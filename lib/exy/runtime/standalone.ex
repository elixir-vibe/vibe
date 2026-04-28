defmodule Exy.Runtime.Standalone do
  @moduledoc """
  Stateful standalone BEAM runtime for Livebook-style script evaluation.

  This runtime starts a separate `elixir` OS process and talks to it with
  Erlang external terms over a packetized port. The child keeps `binding` and
  `Macro.Env` between evaluations, so aliases/imports/variables and
  `Mix.install/2` state stay out of Exy's main VM.
  """

  use GenServer

  @behaviour Exy.Runtime

  @default_timeout_ms 30_000
  @call_overhead_ms 1_000

  @impl Exy.Runtime
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  @impl Exy.Runtime
  def evaluate(runtime, code, opts \\ []) when is_binary(code) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    GenServer.call(runtime, {:evaluate, code, opts}, timeout + @call_overhead_ms)
  end

  @impl Exy.Runtime
  def stop(runtime), do: GenServer.stop(runtime, :normal)

  @impl true
  def init(opts) do
    executable = Keyword.get(opts, :elixir, System.find_executable("elixir") || "elixir")
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    env = Keyword.get(opts, :env, %{})

    runtime = %{executable: executable, cwd: cwd, env: env}
    {:ok, Map.merge(runtime, %{port: open_port(runtime), next_id: 1, requests: %{}})}
  end

  @impl true
  def handle_call({:evaluate, code, opts}, from, state) do
    id = state.next_id
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    message = {:eval, id, code, Keyword.take(opts, [:file])}
    Port.command(state.port, encode(message))
    timer = Process.send_after(self(), {:request_timeout, id}, timeout)

    state = %{
      state
      | next_id: id + 1,
        requests: Map.put(state.requests, id, %{from: from, timer: timer})
    }

    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, packet}}, %{port: port} = state) do
    case decode(packet) do
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

  def handle_info({:request_timeout, id}, state) do
    {request, requests} = Map.pop(state.requests, id)

    if request do
      GenServer.reply(
        request.from,
        {:ok, %{status: :timeout, value: nil, output: "", diagnostics: []}}
      )
    end

    state = %{state | requests: requests}
    state = restart_runtime(state, {:request_timeout, id})
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    state = fail_all(state, {:runtime_exited, status})
    {:noreply, %{state | port: open_port(state)}}
  end

  def handle_info({_port, {:exit_status, _status}}, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    if Port.info(state.port), do: Port.close(state.port)
    :ok
  rescue
    _ -> :ok
  end

  defp child_args do
    [
      "--erl",
      "+sbwt none +sbwtdcpu none +sbwtdio none",
      "--eval",
      child_code() |> Macro.to_string()
    ]
  end

  defp child_code do
    quote do
      defmodule ExyRuntimeChild do
        def run do
          Logger.configure(level: :none)
          context = %{binding: [], env: Code.env_for_eval([])}
          loop(context)
        end

        defp loop(context) do
          case read_packet() do
            :eof ->
              :ok

            {:error, _reason} ->
              :ok

            packet ->
              {reply, context} = handle(packet, context)
              payload = :erlang.term_to_binary(reply)
              write_packet(payload)
              loop(context)
          end
        end

        defp read_packet do
          with <<size::32>> <- IO.binread(:stdio, 4),
               packet when is_binary(packet) <- IO.binread(:stdio, size) do
            packet
          end
        end

        defp write_packet(payload) do
          :file.write(:standard_io, <<byte_size(payload)::32, payload::binary>>)
        catch
          :exit, _reason -> :ok
        end

        defp handle(packet, context) do
          case :erlang.binary_to_term(packet) do
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

  defp restart_runtime(state, reason) do
    state
    |> close_port()
    |> fail_all({:runtime_restarted, reason})
    |> then(&%{&1 | port: open_port(&1)})
  end

  defp open_port(runtime) do
    Port.open({:spawn_executable, runtime.executable}, [
      :binary,
      :exit_status,
      {:packet, 4},
      args: child_args(),
      cd: runtime.cwd,
      env: normalize_env(runtime.env)
    ])
  end

  defp close_port(state) do
    if Port.info(state.port), do: Port.close(state.port)
    state
  rescue
    _ -> state
  end

  defp encode(term), do: :erlang.term_to_binary(term)
  defp decode(packet), do: :erlang.binary_to_term(packet)

  defp normalize_env(env) when is_map(env), do: env |> Map.to_list() |> normalize_env()

  defp normalize_env(env),
    do: Enum.map(env, fn {key, value} -> {to_charlist(key), to_charlist(value)} end)
end
