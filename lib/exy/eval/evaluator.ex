defmodule Exy.Eval.Evaluator do
  @moduledoc false

  use GenServer

  alias Exy.Session.Store
  alias Exy.ToolOutput

  @inspect_opts [charlists: :as_lists, limit: 80, pretty: true]

  defstruct session_id: nil,
            binding: [],
            env: nil,
            persist?: true

  @type result :: {:ok, String.t()} | {:error, String.t()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: via(session_id))
  end

  @spec evaluate(GenServer.server(), String.t()) :: result()
  def evaluate(server, code) when is_binary(code),
    do: GenServer.call(server, {:evaluate, code}, :infinity)

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

  defp eval_with_captured_io(code, state) do
    {{success?, result, state}, io} = capture_io(fn -> eval_code(code, state) end)

    cond do
      success? and io == "" ->
        {{:ok, result |> inspect(@inspect_opts) |> ToolOutput.limit_text()}, state}

      success? ->
        {{:ok,
          ToolOutput.limit_text("IO:\n\n#{io}\n\nResult:\n\n#{inspect(result, @inspect_opts)}")},
         state}

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

          state = %{state | binding: binding, env: env}
          persist_bindings(state)
          {true, result, state}
        end)

      result
    catch
      kind, reason -> {false, Exception.format(kind, reason, __STACKTRACE__), state}
    end
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
    {_result, _binding, env} =
      "import IEx.Helpers, warn: false"
      |> Code.string_to_quoted!()
      |> Code.eval_quoted_with_env([], Code.env_for_eval([]), prune_binding: true)

    plugin_env(env)
  end

  defp plugin_env(env) do
    aliases = Enum.map(Exy.Plugin.Manager.apis(), &{&1.alias, &1.module})
    %{env | aliases: Keyword.merge(env.aliases, aliases)}
  end

  defp eval_file(session_id), do: "exy://session/#{session_id}/eval"

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

  defp serializable_term?(term) when is_map(term) do
    Enum.all?(term, fn {key, value} -> serializable_term?(key) and serializable_term?(value) end)
  end

  defp serializable_term?(_term), do: true

  defp via(session_id), do: {:via, Registry, {Exy.Registry, {:eval, session_id}}}
end
