defmodule Exy.Eval.Evaluator do
  @moduledoc false

  use GenServer

  alias Exy.Eval.Result
  alias Exy.Session.Store
  alias Exy.ToolOutput

  @inspect_opts [charlists: :as_lists, limit: 80, pretty: true]

  defstruct session_id: nil,
            binding: [],
            env: nil,
            persist?: true

  @type result :: {:ok, Result.t()} | {:error, String.t()}
  @type binding_info :: %{
          name: atom(),
          type: atom() | module(),
          bytes: non_neg_integer(),
          preview: String.t()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: via(session_id))
  end

  @spec evaluate(GenServer.server(), String.t()) :: result()
  def evaluate(server, code) when is_binary(code),
    do: GenServer.call(server, {:evaluate, code}, :infinity)

  @spec bindings(GenServer.server()) :: [binding_info()]
  def bindings(server), do: GenServer.call(server, :bindings)

  @spec forget(GenServer.server(), [atom()]) :: :ok
  def forget(server, names) when is_list(names), do: GenServer.call(server, {:forget, names})

  @spec reset(GenServer.server()) :: :ok
  def reset(server), do: GenServer.call(server, :reset)

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    persist? = Keyword.get(opts, :persist?, true)

    {binding, env} = initial_context(session_id, persist?)

    {:ok,
     %__MODULE__{
       session_id: session_id,
       binding: binding,
       env: env,
       persist?: persist?
     }}
  end

  @impl true
  def handle_call({:evaluate, code}, _from, state) do
    {reply, state} = eval_with_captured_io(code, state)
    {:reply, reply, state}
  end

  def handle_call(:bindings, _from, state) do
    {:reply, Enum.map(state.binding, &binding_info/1), state}
  end

  def handle_call({:forget, names}, _from, state) do
    names = MapSet.new(names)

    state = %{
      state
      | binding: Enum.reject(state.binding, fn {name, _value} -> MapSet.member?(names, name) end),
        env: prune_env_vars(state.env, names)
    }

    persist_bindings(state)
    {:reply, :ok, state}
  end

  def handle_call(:reset, _from, state) do
    state = %{state | binding: [], env: initial_env()}
    persist_bindings(state)
    {:reply, :ok, state}
  end

  defp eval_with_captured_io(code, state) do
    {{success?, result, state}, io} =
      capture_io(fn ->
        Exy.Command.Streaming.with_eval_session(state.session_id, fn -> eval_code(code, state) end)
      end)

    cond do
      success? and io == "" ->
        {{:ok, display_result(result)}, state}

      success? ->
        {{:ok, io_result(result, io)}, state}

      io != "" ->
        error = [ToolOutput.limit_text(io), "\n", ToolOutput.limit_text(result)]
        {{:error, IO.iodata_to_binary(error)}, state}

      true ->
        {{:error, ToolOutput.limit_text(result)}, state}
    end
  end

  defp eval_code(code, state) do
    try do
      {result, _diagnostics} =
        Code.with_diagnostics([log: false], fn ->
          quoted = Code.string_to_quoted!(code, file: eval_file(state.session_id))
          env = plugin_env(state.env)

          {result, binding, env} =
            Code.eval_quoted_with_env(quoted, state.binding, env, prune_binding: true)

          state = %{state | binding: merge_binding(state.binding, binding), env: env}
          persist_bindings(state)
          {true, result, state}
        end)

      result
    catch
      kind, reason -> {false, Exception.format(kind, reason, __STACKTRACE__), state}
    end
  end

  defp display_result(%Exy.MD.Doc{} = doc) do
    %Result{
      output: ToolOutput.limit_text(doc.markdown),
      format: :markdown,
      value_type: Exy.MD.Doc
    }
  end

  defp display_result(%Exy.Command.Result{} = command) do
    %Result{
      output: ToolOutput.limit_text(command.output),
      format: :text,
      value_type: Exy.Command.Result
    }
  end

  defp display_result(result) do
    %Result{
      output: result |> inspect(@inspect_opts) |> ToolOutput.limit_text(),
      format: :inspect,
      value_type: value_type(result)
    }
  end

  defp io_result(result, io) do
    if boring_result?(result) do
      %Result{
        output: ToolOutput.limit_text(io),
        format: :text,
        parts: [%{output: ToolOutput.limit_text(io), format: :text}],
        io: io,
        value_type: value_type(result)
      }
    else
      inspected = result |> inspect(@inspect_opts) |> ToolOutput.limit_text()

      %Result{
        output: [io, "\n", inspected] |> IO.iodata_to_binary() |> ToolOutput.limit_text(),
        format: :text,
        parts: [
          %{output: ToolOutput.limit_text(io), format: :text},
          %{output: inspected, format: :inspect}
        ],
        io: io,
        value_type: value_type(result)
      }
    end
  end

  defp boring_result?(result),
    do: result in [:ok, nil, :done, :"do not show this result in output"]

  defp merge_binding(previous, current) do
    current_names = MapSet.new(current, &elem(&1, 0))
    current ++ Enum.reject(previous, fn {name, _value} -> MapSet.member?(current_names, name) end)
  end

  defp persist_bindings(%{persist?: false}), do: :ok

  defp persist_bindings(state) do
    binding = Enum.filter(state.binding, fn {_name, value} -> serializable_term?(value) end)
    Store.append_eval_state(binding, state.env, session_id: state.session_id)
  end

  defp initial_context(session_id, true) do
    case Store.eval_state(session_id) do
      %{binding: binding, env: %Macro.Env{} = env} -> {binding, plugin_env(env)}
      nil -> {[], initial_env()}
    end
  end

  defp initial_context(_session_id, false), do: {[], initial_env()}

  defp initial_env do
    env = Code.env_for_eval([])

    if Code.ensure_loaded?(IEx.Helpers) do
      {_result, _binding, env} =
        "import IEx.Helpers, warn: false"
        |> Code.string_to_quoted!()
        |> Code.eval_quoted_with_env([], env, prune_binding: true)

      plugin_env(env)
    else
      plugin_env(env)
    end
  end

  defp plugin_env(env) do
    aliases =
      [{Cmd, Exy.Command}, {MD, Exy.MD}] ++
        Enum.map(
          Exy.Plugin.Manager.apis() ++ Exy.Skill.apis(),
          &{Module.concat([&1.alias]), &1.module}
        )

    %{env | aliases: Keyword.merge(env.aliases, aliases)}
  end

  defp eval_file(session_id), do: "exy://session/#{session_id}/eval"

  defp binding_info({name, value}) do
    %{
      name: name,
      type: value_type(value),
      bytes: value_bytes(value),
      preview: value |> inspect(@inspect_opts) |> ToolOutput.limit_text()
    }
  end

  defp value_type(%module{}), do: module
  defp value_type(value) when is_binary(value), do: :binary
  defp value_type(value) when is_atom(value), do: :atom
  defp value_type(value) when is_boolean(value), do: :boolean
  defp value_type(value) when is_integer(value), do: :integer
  defp value_type(value) when is_float(value), do: :float
  defp value_type(value) when is_list(value), do: :list
  defp value_type(value) when is_tuple(value), do: :tuple
  defp value_type(value) when is_map(value), do: :map
  defp value_type(value) when is_function(value), do: :function
  defp value_type(value) when is_pid(value), do: :pid
  defp value_type(value) when is_port(value), do: :port
  defp value_type(value) when is_reference(value), do: :reference
  defp value_type(_value), do: :term

  defp value_bytes(value), do: value |> :erlang.term_to_binary() |> byte_size()

  defp prune_env_vars(env, names) do
    Map.update!(env, :versioned_vars, fn versioned_vars ->
      Map.reject(versioned_vars, fn {{name, _context}, _version} ->
        MapSet.member?(names, name)
      end)
    end)
  end

  defp capture_io(fun) do
    {:ok, io} = StringIO.open("")
    ansi? = Application.get_env(:elixir, :ansi_enabled)
    original_gl = Process.group_leader()

    Application.put_env(:elixir, :ansi_enabled, false)
    Process.group_leader(self(), io)

    try do
      result = fun.()
      {_, content} = StringIO.contents(io)
      {result, content}
    after
      Process.group_leader(self(), original_gl)
      StringIO.close(io)
      Application.put_env(:elixir, :ansi_enabled, ansi?)
    end
  end

  defp serializable_term?(term)
       when is_pid(term) or is_port(term) or is_reference(term) or is_function(term),
       do: false

  defp serializable_term?(term) when is_list(term), do: Enum.all?(term, &serializable_term?/1)

  defp serializable_term?(term) when is_tuple(term) do
    term
    |> Tuple.to_list()
    |> Enum.all?(&serializable_term?/1)
  end

  defp serializable_term?(%_module{} = term) do
    term
    |> Map.from_struct()
    |> serializable_term?()
  end

  defp serializable_term?(term) when is_map(term) do
    Enum.all?(term, fn {key, value} -> serializable_term?(key) and serializable_term?(value) end)
  end

  defp serializable_term?(_term), do: true

  defp via(session_id), do: {:via, Registry, {Exy.Registry, {:eval, session_id}}}
end
