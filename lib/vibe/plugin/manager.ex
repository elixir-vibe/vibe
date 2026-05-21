defmodule Vibe.Plugin.Manager do
  @moduledoc "Supervised plugin lifecycle, discovery, and dispatch."
  use GenServer

  require Logger

  alias Vibe.Plugin.API
  alias Vibe.UI.Document

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

  @spec system_prompt_blocks(map()) :: [String.t()]
  def system_prompt_blocks(context \\ %{}) do
    GenServer.call(__MODULE__, {:system_prompt_blocks, context})
  end

  @spec before_command(String.t(), map()) :: :ok | {:warn, String.t()} | {:block, String.t()}
  def before_command(command, context \\ %{}) do
    GenServer.call(__MODULE__, {:before_command, command, context})
  end

  @spec tool_call(map(), map()) :: :ok | {:ok, map()} | {:block, String.t()}
  def tool_call(call, context \\ %{}),
    do: GenServer.call(__MODULE__, {:tool_call, call, context})

  @spec tool_result(map(), map()) :: :ok | {:ok, map()}
  def tool_result(result, context \\ %{}),
    do: GenServer.call(__MODULE__, {:tool_result, result, context})

  @spec context(list(), map()) :: {:ok, list()} | list()
  def context(messages, context \\ %{}),
    do: GenServer.call(__MODULE__, {:context, messages, context})

  @spec plugins() :: [module()]
  def plugins, do: GenServer.call(__MODULE__, :plugins)

  @spec commands() :: [module()]
  def commands, do: GenServer.call(__MODULE__, :commands)

  @spec apis() :: [API.t()]
  def apis, do: GenServer.call(__MODULE__, :apis)

  @spec ui_document(module()) :: Document.t()
  def ui_document(module), do: GenServer.call(__MODULE__, {:ui_document, module})

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
      result =
        Vibe.Telemetry.span([:vibe, :plugin, :load], %{plugin: module}, fn ->
          start_plugin(module, opts)
        end)

      case result do
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

  def handle_call({:tool_call, call, context}, _from, state) do
    {result, state} = pipeline_callback(:tool_call, [call, context], state)
    {:reply, result, state}
  end

  def handle_call({:tool_result, result, context}, _from, state) do
    {reply, state} = pipeline_callback(:tool_result, [result, context], state)
    {:reply, reply, state}
  end

  def handle_call({:context, messages, context}, _from, state) do
    {reply, state} = pipeline_callback(:context, [messages, context], state)
    {:reply, reply, state}
  end

  def handle_call({:system_prompt_blocks, context}, _from, state) do
    {blocks, state} = collect_system_prompts(state, context)
    {:reply, blocks, state}
  end

  def handle_call({:before_command, command, context}, _from, state) do
    {result, state} = run_before_command(state, command, context)
    {:reply, result, state}
  end

  def handle_call(:commands, _from, state) do
    commands =
      state.plugins
      |> Enum.flat_map(fn {module, entry} -> plugin_commands(module, entry.state) end)
      |> Enum.uniq()

    {:reply, commands, state}
  end

  def handle_call(:apis, _from, state) do
    apis =
      state.plugins
      |> Enum.flat_map(fn {module, entry} -> plugin_apis(module, entry.state) end)
      |> Enum.uniq_by(&{&1.alias, &1.module})

    {:reply, apis, state}
  end

  def handle_call({:ui_document, module}, _from, state) do
    document =
      case Map.fetch(state.plugins, module) do
        {:ok, entry} -> plugin_ui_document(module, entry.state)
        :error -> Document.empty()
      end

    {:reply, document, state}
  end

  def handle_call({:dispatch, event, context}, _from, state) do
    {result, state} =
      Vibe.Telemetry.span([:vibe, :plugin, :dispatch], dispatch_metadata(event, context), fn ->
        do_dispatch(Map.to_list(state.plugins), event, context, state, [])
      end)

    {:reply, result, state}
  end

  defp dispatch_metadata(event, context) do
    %{
      event_type: Map.get(event, :type),
      session_id: Map.get(context, :session_id)
    }
  end

  defp start_plugin(module, opts) do
    context = Vibe.Plugin.Context.from_opts(opts)

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
        Enum.each(children, &DynamicSupervisor.terminate_child(Vibe.Plugin.Supervisor, &1))
        {:error, reason}
    end
  end

  defp start_child(module, child_spec, {:ok, children}) do
    case DynamicSupervisor.start_child(
           Vibe.Plugin.Supervisor,
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
    error ->
      Logger.warning("Plugin #{inspect(module)} commands/1 failed: #{Exception.message(error)}")
      []
  end

  defp plugin_apis(module, plugin_state) do
    if function_exported?(module, :apis, 1) do
      Enum.map(module.apis(plugin_state), &Vibe.Plugin.API.new/1)
    else
      []
    end
  rescue
    error ->
      Logger.warning("Plugin #{inspect(module)} apis/1 failed: #{Exception.message(error)}")
      []
  end

  defp plugin_ui_document(module, plugin_state) do
    if function_exported?(module, :ui_document, 1) do
      Document.new(module.ui_document(plugin_state))
    else
      Document.empty()
    end
  rescue
    error ->
      Logger.warning(
        "Plugin #{inspect(module)} ui_document/1 failed: #{Exception.message(error)}"
      )

      Document.empty()
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
        Enum.each(entry.children, &DynamicSupervisor.terminate_child(Vibe.Plugin.Supervisor, &1))
        safe_shutdown(module, entry.state)
        %{state | plugins: plugins}
    end
  end

  defp configured_plugins do
    Vibe.Plugin.Discovery.builtin()
    |> Vibe.Support.Lists.join(Application.get_env(:vibe, :plugins, []))
    |> Enum.uniq()
  end

  defp collect_system_prompts(state, context) do
    Enum.reduce(Map.to_list(state.plugins), {[], state}, fn {module, entry}, {blocks, state} ->
      safe_system_prompt(module, entry, context, blocks, state)
    end)
    |> then(fn {blocks, state} -> {Enum.reverse(blocks), state} end)
  end

  defp safe_system_prompt(module, entry, context, blocks, state) do
    if function_exported?(module, :system_prompt, 2) do
      case module.system_prompt(context, entry.state) do
        {text, new_state} when is_binary(text) and text != "" ->
          {[text | blocks], put_plugin_state(state, module, new_state)}

        {_nil_or_empty, new_state} ->
          {blocks, put_plugin_state(state, module, new_state)}
      end
    else
      {blocks, state}
    end
  rescue
    error ->
      Logger.warning(
        "Plugin #{inspect(module)} system_prompt/2 failed: #{Exception.message(error)}"
      )

      {blocks, state}
  end

  defp run_before_command(state, command, context) do
    Enum.reduce_while(Map.to_list(state.plugins), {:ok, state}, fn {module, entry}, acc ->
      safe_before_command(module, entry, command, context, acc)
    end)
    |> then(fn
      {:ok, state} -> {:ok, state}
      {{:warn, label}, state} -> {{:warn, label}, state}
      {{:block, reason}, state} -> {{:block, reason}, state}
    end)
  end

  defp safe_before_command(module, entry, command, context, {:ok, state}) do
    if function_exported?(module, :before_command, 3) do
      case module.before_command(command, context, entry.state) do
        {:ok, new_state} ->
          {:cont, {:ok, put_plugin_state(state, module, new_state)}}

        {:warn, label, new_state} ->
          {:cont, {{:warn, label}, put_plugin_state(state, module, new_state)}}

        {:block, reason, new_state} ->
          {:halt, {{:block, reason}, put_plugin_state(state, module, new_state)}}
      end
    else
      {:cont, {:ok, state}}
    end
  rescue
    error ->
      Logger.warning(
        "Plugin #{inspect(module)} before_command/3 failed: #{Exception.message(error)}"
      )

      {:cont, {:ok, state}}
  end

  defp pipeline_callback(callback, args, state) do
    Enum.reduce_while(Map.to_list(state.plugins), {:ok, state}, fn {module, entry}, acc ->
      safe_pipeline_step(module, entry, callback, args, acc)
    end)
  end

  defp safe_pipeline_step(module, entry, callback, args, {:ok, state}) do
    full_args = List.insert_at(args, -1, entry.state)

    if function_exported?(module, callback, length(full_args)) do
      case apply(module, callback, full_args) do
        {:ok, new_state} ->
          {:cont, {:ok, put_plugin_state(state, module, new_state)}}

        {:ok, modified, new_state} ->
          {:cont, {{:ok, modified}, put_plugin_state(state, module, new_state)}}

        {:block, reason, new_state} ->
          {:halt, {{:block, reason}, put_plugin_state(state, module, new_state)}}
      end
    else
      {:cont, {:ok, state}}
    end
  rescue
    error ->
      Logger.warning("Plugin #{inspect(module)} #{callback} failed: #{Exception.message(error)}")
      {:cont, {:ok, state}}
  end

  defp safe_pipeline_step(_module, _entry, _callback, _args, acc), do: {:cont, acc}

  defp safe_shutdown(module, plugin_state) do
    if function_exported?(module, :shutdown, 1), do: module.shutdown(plugin_state), else: :ok
  rescue
    error ->
      Logger.warning("Plugin #{inspect(module)} shutdown/1 failed: #{Exception.message(error)}")
      :ok
  end
end
