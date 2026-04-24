defmodule Exy.Plugin.Manager do
  @moduledoc false

  use GenServer

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

  @impl true
  def init(opts) do
    modules = Keyword.get(opts, :plugins, configured_plugins())

    state =
      Enum.reduce(modules, %{}, fn module, acc ->
        case module.init([]) do
          {:ok, plugin_state} -> Map.put(acc, module, plugin_state)
          _ -> acc
        end
      end)

    {:ok, state}
  end

  @impl true
  def handle_call({:load, module, opts}, _from, state) do
    case module.init(opts) do
      {:ok, plugin_state} -> {:reply, :ok, Map.put(state, module, plugin_state)}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unload, module}, _from, state) do
    state =
      case Map.pop(state, module) do
        {nil, state} ->
          state

        {plugin_state, state} ->
          safe_shutdown(module, plugin_state)
          state
      end

    {:reply, :ok, state}
  end

  def handle_call(:plugins, _from, state), do: {:reply, Map.keys(state), state}

  def handle_call({:dispatch, event, context}, _from, state) do
    {result, state} = do_dispatch(Map.to_list(state), event, context, state, [])
    {:reply, result, state}
  end

  defp do_dispatch([], _event, _context, state, results),
    do: {{:ok, Enum.reverse(results)}, state}

  defp do_dispatch([{module, plugin_state} | rest], event, context, state, results) do
    case module.handle_event(event, context, plugin_state) do
      {{:halt, reason}, new_plugin_state} ->
        {{:halt, reason}, Map.put(state, module, new_plugin_state)}

      {{:error, reason}, new_plugin_state} ->
        {{:error, {module, reason}}, Map.put(state, module, new_plugin_state)}

      {result, new_plugin_state} ->
        do_dispatch(rest, event, context, Map.put(state, module, new_plugin_state), [
          result | results
        ])
    end
  rescue
    exception -> {{:error, {module, exception}}, state}
  end

  defp configured_plugins do
    Exy.Plugin.Discovery.builtin()
    |> Exy.Lists.join(Application.get_env(:exy, :plugins, []))
    |> Enum.uniq()
  end

  defp safe_shutdown(module, plugin_state) do
    if function_exported?(module, :shutdown, 1), do: module.shutdown(plugin_state), else: :ok
  rescue
    _ -> :ok
  end
end
