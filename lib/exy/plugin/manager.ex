defmodule Exy.Plugin.Manager do
  @moduledoc false

  use GenServer

  defstruct plugins: %{}

  @type plugin_entry :: %{state: term(), children: [pid()]}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec load(module(), keyword()) :: :ok | {:error, term()}
  def load(module, opts \\ []), do: GenServer.call(__MODULE__, {:load, module, opts})

  @spec unload(module()) :: :ok
  def unload(module), do: GenServer.call(__MODULE__, {:unload, module})

  @spec dispatch(atom(), map(), map()) :: {:ok, [term()]} | {:halt, term()} | {:error, term()}
  def dispatch(type, payload \\ %{}, context \\ %{}) when is_atom(type) and is_map(payload) do
    GenServer.call(__MODULE__, {:dispatch, Map.put(payload, :type, type), context})
  end

  @spec plugins() :: [module()]
  def plugins, do: GenServer.call(__MODULE__, :plugins)

  @spec commands() :: [module()]
  def commands, do: GenServer.call(__MODULE__, :commands)

  @impl true
  def init(opts) do
    modules = Keyword.get(opts, :plugins, configured_plugins())

    plugins =
      Enum.reduce(modules, %{}, fn module, acc ->
        case start_plugin(module, []) do
          {:ok, entry} -> Map.put(acc, module, entry)
          _ -> acc
        end
      end)

    {:ok, %__MODULE__{plugins: plugins}}
  end

  @impl true
  def handle_call({:load, module, opts}, _from, state) do
    if Map.has_key?(state.plugins, module) do
      {:reply, {:error, :already_loaded}, state}
    else
      case start_plugin(module, opts) do
        {:ok, entry} -> {:reply, :ok, put_plugin(state, module, entry)}
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    end
  end

  def handle_call({:unload, module}, _from, state) do
    state = unload_plugin(state, module)
    {:reply, :ok, state}
  end

  def handle_call(:plugins, _from, state), do: {:reply, Map.keys(state.plugins), state}

  def handle_call(:commands, _from, state) do
    commands =
      state.plugins
      |> Enum.flat_map(fn {module, entry} -> plugin_commands(module, entry.state) end)
      |> Enum.uniq()

    {:reply, commands, state}
  end

  def handle_call({:dispatch, event, context}, _from, state) do
    {result, state} = do_dispatch(Map.to_list(state.plugins), event, context, state, [])
    {:reply, result, state}
  end

  defp start_plugin(module, opts) do
    context = Exy.Plugin.Context.from_opts(opts)

    with {:ok, plugin_state} <- module.init(opts),
         {:ok, children} <- start_children(module, plugin_state, context) do
      {:ok, %{state: plugin_state, children: children}}
    end
  end

  defp start_children(module, plugin_state, context) do
    children =
      cond do
        function_exported?(module, :children, 2) -> module.children(plugin_state, context)
        function_exported?(module, :children, 1) -> module.children(plugin_state)
        true -> []
      end

    case Enum.reduce_while(children, {:ok, []}, &start_child(module, &1, &2)) do
      {:ok, children} ->
        {:ok, children}

      {:error, reason, children} ->
        Enum.each(children, &DynamicSupervisor.terminate_child(Exy.Plugin.Supervisor, &1))
        {:error, reason}
    end
  end

  defp start_child(module, child_spec, {:ok, children}) do
    case DynamicSupervisor.start_child(
           Exy.Plugin.Supervisor,
           normalize_child_spec(module, child_spec)
         ) do
      {:ok, pid} when is_pid(pid) -> {:cont, {:ok, [pid | children]}}
      {:ok, pid, _info} when is_pid(pid) -> {:cont, {:ok, [pid | children]}}
      :ignore -> {:cont, {:ok, children}}
      {:error, {:already_started, pid}} -> {:cont, {:ok, [pid | children]}}
      {:error, reason} -> {:halt, {:error, reason, children}}
    end
  rescue
    exception -> {:halt, {:error, exception, children}}
  end

  defp normalize_child_spec(_module, child_spec) when is_map(child_spec), do: child_spec
  defp normalize_child_spec(_module, child_spec) when is_atom(child_spec), do: child_spec
  defp normalize_child_spec(_module, {child_module, arg}), do: {child_module, arg}

  defp do_dispatch([], _event, _context, state, results),
    do: {{:ok, Enum.reverse(results)}, state}

  defp do_dispatch([{module, entry} | rest], event, context, state, results) do
    case module.handle_event(event, context, entry.state) do
      {{:halt, reason}, new_plugin_state} ->
        {{:halt, reason}, put_plugin_state(state, module, new_plugin_state)}

      {{:error, reason}, new_plugin_state} ->
        {{:error, {module, reason}}, put_plugin_state(state, module, new_plugin_state)}

      {result, new_plugin_state} ->
        state = put_plugin_state(state, module, new_plugin_state)
        do_dispatch(rest, event, context, state, [result | results])
    end
  rescue
    exception -> {{:error, {module, exception}}, state}
  end

  defp plugin_commands(module, plugin_state) do
    if function_exported?(module, :commands, 1), do: module.commands(plugin_state), else: []
  rescue
    _ -> []
  end

  defp put_plugin(%__MODULE__{} = state, module, entry) do
    %{state | plugins: Map.put(state.plugins, module, entry)}
  end

  defp put_plugin_state(%__MODULE__{} = state, module, plugin_state) do
    update_in(state.plugins[module].state, fn _old_state -> plugin_state end)
  end

  defp unload_plugin(%__MODULE__{} = state, module) do
    case Map.pop(state.plugins, module) do
      {nil, plugins} ->
        %{state | plugins: plugins}

      {entry, plugins} ->
        Enum.each(entry.children, &DynamicSupervisor.terminate_child(Exy.Plugin.Supervisor, &1))
        safe_shutdown(module, entry.state)
        %{state | plugins: plugins}
    end
  end

  defp configured_plugins do
    Exy.Plugin.Discovery.builtin()
    |> Exy.Support.Lists.join(Application.get_env(:exy, :plugins, []))
    |> Enum.uniq()
  end

  defp safe_shutdown(module, plugin_state) do
    if function_exported?(module, :shutdown, 1), do: module.shutdown(plugin_state), else: :ok
  rescue
    _ -> :ok
  end
end
