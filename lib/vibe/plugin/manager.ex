defmodule Vibe.Plugin.Manager do
  @moduledoc "Supervised plugin lifecycle, discovery, and dispatch."
  use GenServer

  require Logger

  alias Vibe.Plugin.API
  alias Vibe.Presentation.Document

  @default_plugin_callback_timeout_ms 5_000

  defstruct plugins: %{}, order: []

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

  @spec presentation_document(module()) :: Document.t()
  def presentation_document(module),
    do: GenServer.call(__MODULE__, {:presentation_document, module})

  @impl true
  def init(opts) do
    modules = Keyword.get(opts, :plugins, configured_plugins())

    {plugins, order} =
      Enum.reduce(modules, {%{}, []}, fn module, {plugins, order} ->
        case start_plugin(module, []) do
          {:ok, entry} -> {Map.put(plugins, module, entry), [module | order]}
          _ -> {plugins, order}
        end
      end)

    {:ok, %__MODULE__{plugins: plugins, order: Enum.reverse(order)}}
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
    {result, state} = pipeline_callback(:tool_call, call, context, state)
    {:reply, result, state}
  end

  def handle_call({:tool_result, result, context}, _from, state) do
    {reply, state} = pipeline_callback(:tool_result, result, context, state)
    {:reply, reply, state}
  end

  def handle_call({:context, messages, context}, _from, state) do
    {reply, state} = pipeline_callback(:context, messages, context, state)
    {:reply, reply, state}
  end

  def handle_call({:system_prompt_blocks, context}, _from, state) do
    {blocks, state} = collect_system_prompts(state, context)
    {:reply, blocks, state}
  end

  def handle_call({:before_command, command, context}, from, state) do
    caller = self()
    plugins = ordered_plugins(state)

    {:ok, _pid} =
      Task.start(fn ->
        {result, plugin_states} = run_before_command(plugins, command, context)
        GenServer.reply(from, result)
        send(caller, {:plugin_states_updated, plugin_states})
      end)

    {:noreply, state}
  end

  def handle_call(:commands, _from, state) do
    commands =
      state
      |> ordered_plugins()
      |> Enum.flat_map(fn {module, entry} -> plugin_commands(module, entry.state) end)
      |> Enum.uniq()

    {:reply, commands, state}
  end

  def handle_call(:apis, _from, state) do
    apis =
      state
      |> ordered_plugins()
      |> Enum.flat_map(fn {module, entry} -> plugin_apis(module, entry.state) end)
      |> Enum.uniq_by(&{&1.alias, &1.module})

    {:reply, apis, state}
  end

  def handle_call({:presentation_document, module}, _from, state) do
    document =
      case Map.fetch(state.plugins, module) do
        {:ok, entry} -> plugin_presentation_document(module, entry.state)
        :error -> Document.empty()
      end

    {:reply, document, state}
  end

  def handle_call({:dispatch, event, context}, _from, state) do
    {result, state} =
      Vibe.Telemetry.span([:vibe, :plugin, :dispatch], dispatch_metadata(event, context), fn ->
        do_dispatch(ordered_plugins(state), event, context, state, [])
      end)

    {:reply, result, state}
  end

  @impl true
  def handle_info({:plugin_states_updated, plugin_states}, state) do
    {:noreply, apply_plugin_state_changes(state, plugin_states)}
  end

  defp ordered_plugins(%__MODULE__{} = state) do
    Enum.flat_map(state.order, fn module ->
      case Map.fetch(state.plugins, module) do
        {:ok, entry} -> [{module, entry}]
        :error -> []
      end
    end)
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
    case call_plugin(module, :handle_event, [event, context, entry.state]) do
      {:ok, {{:halt, reason}, new_plugin_state}} ->
        {{:halt, reason}, put_plugin_state(state, module, new_plugin_state)}

      {:ok, {{:error, reason}, new_plugin_state}} ->
        {{:error, {module, reason}}, put_plugin_state(state, module, new_plugin_state)}

      {:ok, {result, new_plugin_state}} ->
        state = put_plugin_state(state, module, new_plugin_state)
        do_dispatch(rest, event, context, state, [result | results])

      {:error, reason} ->
        {{:error, {module, reason}}, state}
    end
  end

  defp plugin_commands(module, plugin_state) do
    with true <- function_exported?(module, :commands, 1),
         {:ok, commands} <- call_plugin(module, :commands, [plugin_state]) do
      commands
    else
      false -> []
      {:error, reason} -> log_plugin_failure(module, :commands, reason, [])
    end
  end

  defp plugin_apis(module, plugin_state) do
    with true <- function_exported?(module, :apis, 1),
         {:ok, apis} <- call_plugin(module, :apis, [plugin_state]) do
      Enum.map(apis, &Vibe.Plugin.API.new/1)
    else
      false -> []
      {:error, reason} -> log_plugin_failure(module, :apis, reason, [])
    end
  end

  defp plugin_presentation_document(module, plugin_state) do
    with true <- function_exported?(module, :presentation_document, 1),
         {:ok, document} <- call_plugin(module, :presentation_document, [plugin_state]) do
      Document.new(document)
    else
      false ->
        Document.empty()

      {:error, reason} ->
        log_plugin_failure(module, :presentation_document, reason, Document.empty())
    end
  end

  defp put_plugin(%__MODULE__{} = state, module, entry) do
    %{state | plugins: Map.put(state.plugins, module, entry), order: state.order ++ [module]}
  end

  defp put_plugin_state(%__MODULE__{} = state, module, plugin_state) do
    update_in(state.plugins[module].state, fn _old_state -> plugin_state end)
  end

  defp apply_plugin_state_changes(state, plugin_states) do
    Enum.reduce(plugin_states, state, fn {module, plugin_state}, state ->
      if Map.has_key?(state.plugins, module) do
        put_plugin_state(state, module, plugin_state)
      else
        state
      end
    end)
  end

  defp unload_plugin(%__MODULE__{} = state, module) do
    case Map.pop(state.plugins, module) do
      {nil, plugins} ->
        %{state | plugins: plugins, order: List.delete(state.order, module)}

      {entry, plugins} ->
        Enum.each(entry.children, &DynamicSupervisor.terminate_child(Vibe.Plugin.Supervisor, &1))
        safe_shutdown(module, entry.state)
        %{state | plugins: plugins, order: List.delete(state.order, module)}
    end
  end

  defp configured_plugins do
    Vibe.Plugin.Discovery.builtin()
    |> Vibe.Support.Lists.join(Application.get_env(:vibe, :plugins, []))
    |> Enum.uniq()
  end

  defp collect_system_prompts(state, context) do
    Enum.reduce(ordered_plugins(state), {[], state}, fn {module, entry}, {blocks, state} ->
      safe_system_prompt(module, entry, context, blocks, state)
    end)
    |> then(fn {blocks, state} -> {Enum.reverse(blocks), state} end)
  end

  defp safe_system_prompt(module, entry, context, blocks, state) do
    with true <- function_exported?(module, :system_prompt, 2),
         {:ok, result} <- call_plugin(module, :system_prompt, [context, entry.state]) do
      case result do
        {text, new_state} when is_binary(text) and text != "" ->
          {[text | blocks], put_plugin_state(state, module, new_state)}

        {_nil_or_empty, new_state} ->
          {blocks, put_plugin_state(state, module, new_state)}
      end
    else
      false ->
        {blocks, state}

      {:error, reason} ->
        log_plugin_failure(module, :system_prompt, reason, nil)
        {blocks, state}
    end
  end

  defp run_before_command(plugins, command, context) do
    Enum.reduce_while(plugins, {:ok, []}, fn {module, entry}, acc ->
      safe_before_command(module, entry, command, context, acc)
    end)
    |> then(fn
      {:ok, plugin_states} -> {:ok, plugin_states}
      {{:warn, label}, plugin_states} -> {{:warn, label}, plugin_states}
      {{:block, reason}, plugin_states} -> {{:block, reason}, plugin_states}
    end)
  end

  defp safe_before_command(module, entry, command, context, {result, plugin_states}) do
    with true <- function_exported?(module, :before_command, 3),
         {:ok, reply} <- call_plugin(module, :before_command, [command, context, entry.state]) do
      case reply do
        {:ok, new_state} ->
          {:cont, {result, [{module, new_state} | plugin_states]}}

        {:warn, label, new_state} ->
          {:cont, {{:warn, label}, [{module, new_state} | plugin_states]}}

        {:block, reason, new_state} ->
          {:halt, {{:block, reason}, [{module, new_state} | plugin_states]}}
      end
    else
      false ->
        {:cont, {result, plugin_states}}

      {:error, reason} ->
        log_plugin_failure(module, :before_command, reason, nil)
        {:cont, {result, plugin_states}}
    end
  end

  defp pipeline_callback(callback, initial_value, context, state) do
    state
    |> ordered_plugins()
    |> Enum.reduce_while({:ok, initial_value, false, state}, fn {module, entry}, acc ->
      safe_pipeline_step(module, entry, callback, context, acc)
    end)
    |> pipeline_reply()
  end

  defp safe_pipeline_step(module, entry, callback, context, {:ok, value, changed?, state}) do
    with true <- function_exported?(module, callback, 3),
         {:ok, reply} <- call_plugin(module, callback, [value, context, entry.state]) do
      case reply do
        {:ok, new_state} ->
          {:cont, {:ok, value, changed?, put_plugin_state(state, module, new_state)}}

        {:ok, modified, new_state} ->
          {:cont, {:ok, modified, true, put_plugin_state(state, module, new_state)}}

        {:block, reason, new_state} ->
          {:halt, {{:block, reason}, put_plugin_state(state, module, new_state)}}
      end
    else
      false ->
        {:cont, {:ok, value, changed?, state}}

      {:error, reason} ->
        log_plugin_failure(module, callback, reason, nil)
        {:cont, {:ok, value, changed?, state}}
    end
  end

  defp pipeline_reply({:ok, _value, false, state}), do: {:ok, state}
  defp pipeline_reply({:ok, value, true, state}), do: {{:ok, value}, state}
  defp pipeline_reply({{:block, reason}, state}), do: {{:block, reason}, state}

  defp safe_shutdown(module, plugin_state) do
    with true <- function_exported?(module, :shutdown, 1),
         {:ok, _result} <- call_plugin(module, :shutdown, [plugin_state]) do
      :ok
    else
      false -> :ok
      {:error, reason} -> log_plugin_failure(module, :shutdown, reason, :ok)
    end
  end

  defp call_plugin(module, callback, args) do
    task =
      Task.Supervisor.async_nolink(Vibe.TaskSupervisor, fn -> apply(module, callback, args) end)

    case Task.yield(task, plugin_callback_timeout_ms()) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  rescue
    error -> {:error, error}
  end

  defp plugin_callback_timeout_ms do
    Application.get_env(:vibe, :plugin_callback_timeout_ms, @default_plugin_callback_timeout_ms)
  end

  defp log_plugin_failure(module, callback, reason, fallback) do
    Logger.warning(
      "Plugin #{inspect(module)} #{callback} failed: #{format_plugin_failure(reason)}"
    )

    fallback
  end

  defp format_plugin_failure(%{__struct__: _} = error), do: Exception.message(error)
  defp format_plugin_failure(reason), do: inspect(reason)
end
