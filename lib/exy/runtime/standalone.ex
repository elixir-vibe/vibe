defmodule Exy.Runtime.Standalone do
  @moduledoc """
  Stateful standalone BEAM runtime for Livebook-style script evaluation.

  This runtime starts a separate `elixir` OS process and talks to it with a
  Base64-encoded Erlang term line protocol. The child keeps `binding` and
  `Macro.Env` between evaluations, so aliases/imports/variables and
  `Mix.install/2` state stay out of Exy's main VM.
  """

  use GenServer

  @behaviour Exy.Runtime

  @default_timeout 30_000

  @impl Exy.Runtime
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  @impl Exy.Runtime
  def evaluate(runtime, code, opts \\ []) when is_binary(code) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(runtime, {:evaluate, code, opts}, timeout + 1_000)
  end

  @impl Exy.Runtime
  def stop(runtime), do: GenServer.stop(runtime, :normal)

  @impl true
  def init(opts) do
    executable = Keyword.get(opts, :elixir, System.find_executable("elixir") || "elixir")
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    env = Keyword.get(opts, :env, %{})

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:line, 1_048_576},
        args: child_args(),
        cd: cwd,
        env: normalize_env(env)
      ])

    {:ok, %{port: port, next_id: 1, requests: %{}}}
  end

  @impl true
  def handle_call({:evaluate, code, opts}, from, state) do
    id = state.next_id
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    message = {:eval, id, code, Keyword.take(opts, [:file])}
    Port.command(state.port, encode(message) <> "\n")
    timer = Process.send_after(self(), {:request_timeout, id}, timeout)

    state = %{
      state
      | next_id: id + 1,
        requests: Map.put(state.requests, id, %{from: from, timer: timer})
    }

    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    case decode(line) do
      {:reply, id, reply} ->
        {request, requests} = Map.pop(state.requests, id)

        if request do
          Process.cancel_timer(request.timer)
          GenServer.reply(request.from, {:ok, reply})
        end

        {:noreply, %{state | requests: requests}}

      _ ->
        {:noreply, state}
    end
  rescue
    _exception ->
      {:noreply, state}
  end

  def handle_info({port, {:data, {:noeol, _line}}}, %{port: port} = state), do: {:noreply, state}
  def handle_info({port, {:data, _data}}, %{port: port} = state), do: {:noreply, state}

  def handle_info({:request_timeout, id}, state) do
    {request, requests} = Map.pop(state.requests, id)

    if request do
      GenServer.reply(
        request.from,
        {:ok, %{status: :timeout, value: nil, output: "", diagnostics: []}}
      )
    end

    {:noreply, %{state | requests: requests}}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    {:noreply, fail_all(state, {:runtime_exited, status})}
  end

  @impl true
  def terminate(_reason, state) do
    if Port.info(state.port), do: Port.close(state.port)
    :ok
  rescue
    _ -> :ok
  end

  defp child_args do
    encoded = child_code() |> Macro.to_string() |> Base.encode64()

    [
      "--erl",
      "+sbwt none +sbwtdcpu none +sbwtdio none",
      "--eval",
      "System.argv() |> hd() |> Base.decode64!() |> Code.eval_string()",
      encoded
    ]
  end

  defp child_code do
    quote do
      defmodule ExyRuntimeChild do
        def run do
          context = %{binding: [], env: Code.env_for_eval([])}
          loop(context)
        end

        defp loop(context) do
          case IO.read(:stdio, :line) do
            :eof ->
              :ok

            {:error, _reason} ->
              :ok

            line ->
              {reply, context} = handle(line, context)
              IO.write(:stdio, Base.encode64(:erlang.term_to_binary(reply)) <> "\n")
              loop(context)
          end
        end

        defp handle(line, context) do
          case :erlang.binary_to_term(Base.decode64!(String.trim(line))) do
            {:eval, id, code, opts} ->
              {result, context} = eval(code, opts, context)
              {{:reply, id, result}, context}
          end
        rescue
          exception ->
            {{:reply, :unknown,
              %{
                status: :error,
                value: Exception.message(exception),
                output: "",
                diagnostics: []
              }}, context}
        end

        defp eval(code, opts, context) do
          old_gl = Process.group_leader()
          {:ok, io} = StringIO.open("")
          Process.group_leader(self(), io)

          {result, context} = do_eval(code, opts, context)

          Process.group_leader(self(), old_gl)
          {_input, output} = StringIO.contents(io)
          {Map.put(result, :output, output), context}
        end

        defp do_eval(code, opts, context) do
          env = %{context.env | file: Keyword.get(opts, :file, "nofile")}

          {{result, context}, diagnostics} =
            Code.with_diagnostics([log: true], fn ->
              try do
                quoted = Code.string_to_quoted!(code, file: env.file)

                {value, binding, env} =
                  Code.eval_quoted_with_env(quoted, context.binding, env, prune_binding: true)

                {%{status: :ok, value: value, output: "", diagnostics: []},
                 %{binding: binding, env: env}}
              catch
                kind, reason ->
                  {%{
                     status: :error,
                     value: Exception.format(kind, reason, __STACKTRACE__),
                     output: "",
                     diagnostics: []
                   }, context}
              end
            end)

          diagnostics =
            Enum.map(diagnostics, fn diagnostic ->
              %{
                file: diagnostic.file,
                position: diagnostic.position,
                message: diagnostic.message,
                severity: diagnostic.severity
              }
            end)

          {Map.put(result, :diagnostics, diagnostics), context}
        end
      end

      ExyRuntimeChild.run()
    end
  end

  defp fail_all(state, reason) do
    Enum.each(state.requests, fn {_id, request} ->
      Process.cancel_timer(request.timer)
      GenServer.reply(request.from, {:error, reason})
    end)

    %{state | requests: %{}}
  end

  defp encode(term), do: term |> :erlang.term_to_binary() |> Base.encode64()
  defp decode(line), do: line |> String.trim() |> Base.decode64!() |> :erlang.binary_to_term()

  defp normalize_env(env) when is_map(env), do: env |> Map.to_list() |> normalize_env()

  defp normalize_env(env),
    do: Enum.map(env, fn {key, value} -> {to_charlist(key), to_charlist(value)} end)
end
