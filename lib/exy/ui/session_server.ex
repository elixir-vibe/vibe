defmodule Exy.UI.SessionServer do
  @moduledoc """
  UI-facing session process shared by future TUI and LiveView adapters.

  It owns UI-neutral state, accepts UI-neutral commands, emits events to
  subscribers, and delegates model work through an injectable ask function.
  """

  use GenServer

  alias Exy.LLM.Usage
  alias Exy.UI.{Command, Event, Reducer, State}

  @type ask_fun :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid \\ self()) when is_pid(pid),
    do: GenServer.call(server, {:subscribe, pid})

  @spec state(GenServer.server()) :: State.t()
  def state(server), do: GenServer.call(server, :state)

  @spec dispatch(GenServer.server(), Command.t() | atom() | {atom(), map()}) :: :ok
  def dispatch(server, command),
    do: GenServer.call(server, {:dispatch, normalize_command(command)})

  @spec emit_event(GenServer.server(), Event.t()) :: :ok
  def emit_event(server, %Event{} = event), do: GenServer.call(server, {:emit_event, event})

  @doc false
  @spec agent_ask_opts(keyword()) :: keyword()
  def agent_ask_opts(opts), do: Keyword.drop(opts, [:model])

  @impl true
  def init(opts) do
    state = State.new(opts)

    maybe_register_ui_bus(state.session_id)
    dispatch_plugin_lifecycle(:session_started, %{}, state)

    {:ok,
     %{
       state: state,
       ask_fun: Keyword.get(opts, :ask_fun, &default_ask/2),
       llm_opts: Keyword.take(opts, [:model, :system]),
       streaming?: Keyword.get(opts, :streaming?, not Keyword.has_key?(opts, :ask_fun)),
       subscribers: %{},
       prompt_task: nil,
       prompt_ref: nil,
       active_agent: nil
     }}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    ref = Process.monitor(pid)
    subscribers = Map.put(state.subscribers, ref, pid)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call(:state, _from, state), do: {:reply, state.state, state}

  def handle_call({:dispatch, %Command{} = command}, _from, state) do
    {:reply, :ok, handle_command(command, state)}
  end

  def handle_call({:emit_event, %Event{} = event}, _from, state) do
    {:reply, :ok, emit(state, event)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, ref)}}
  end

  def handle_info({:prompt_result, ref, result}, %{prompt_ref: ref} = state) do
    state = %{state | prompt_task: nil, prompt_ref: nil, active_agent: nil}
    state = record_prompt_result(state, result)
    {:noreply, state}
  end

  def handle_info({:prompt_result, _ref, _result}, state), do: {:noreply, state}

  def handle_info({:active_agent, ref, agent}, %{prompt_ref: ref} = state) when is_pid(agent) do
    {:noreply, %{state | active_agent: agent}}
  end

  def handle_info({:active_agent, _ref, _agent}, state), do: {:noreply, state}

  def handle_info({:assistant_delta, text}, state) do
    {:noreply, emit(state, Event.new(:assistant_delta, state.state.session_id, %{text: text}))}
  end

  def handle_info({:assistant_thinking_delta, text}, state) do
    {:noreply,
     emit(state, Event.new(:assistant_thinking_delta, state.state.session_id, %{text: text}))}
  end

  def handle_info({:tool_started, data}, state) do
    {:noreply, emit(state, Event.new(:tool_started, state.state.session_id, data))}
  end

  def handle_info({:tool_finished, data}, state) do
    {:noreply, emit(state, Event.new(:tool_finished, state.state.session_id, data))}
  end

  defp handle_command(%Command{type: :submit_prompt, data: %{text: text}}, state)
       when is_binary(text) do
    session_id = state.state.session_id
    state = emit(state, Event.new(:prompt_submitted, session_id, %{text: text}))
    state = emit(state, Event.new(:user_message_added, session_id, %{text: text}))
    ask_fun = state.ask_fun
    parent = self()
    ref = make_ref()

    {ask_opts, state} = ask_options(state, parent, ref, session_id)

    {:ok, task} =
      Task.start(fn -> send(parent, {:prompt_result, ref, safe_ask(ask_fun, text, ask_opts)}) end)

    %{state | prompt_task: task, prompt_ref: ref, active_agent: nil}
  end

  defp handle_command(%Command{type: :cancel_stream}, state) do
    cancel_prompt(state)
  end

  defp handle_command(%Command{type: :toggle_truncation}, state) do
    emit(state, Event.new(:truncation_toggled, state.state.session_id, %{}))
  end

  defp handle_command(
         %Command{type: :slash_command_submitted, data: %{command: command} = data},
         state
       ) do
    state = emit(state, Event.new(:slash_command_submitted, state.state.session_id, data))
    run_slash_command(command, Map.get(data, :args, ""), state)
  end

  defp handle_command(%Command{type: :selector_confirmed, data: data}, state) do
    state = emit(state, Event.new(:selector_confirmed, state.state.session_id, data))
    run_selector_action(data, state)
  end

  defp handle_command(%Command{type: :open_overlay, data: data}, state) do
    emit(state, Event.new(:overlay_opened, state.state.session_id, data))
  end

  defp handle_command(%Command{type: :close_overlay}, state) do
    emit(state, Event.new(:overlay_closed, state.state.session_id, %{}))
  end

  defp handle_command(%Command{type: type, data: data}, state) do
    emit(state, Event.new(type, state.state.session_id, data))
  end

  defp ask_options(%{streaming?: true} = state, parent, ref, session_id) do
    state = emit(state, Event.new(:assistant_stream_started, session_id, %{}))

    ask_opts =
      state.llm_opts
      |> Keyword.put(:session_id, session_id)
      |> Keyword.put(:stream_owner, {parent, ref})
      |> Keyword.put(:on_result, &send(parent, {:assistant_delta, &1}))
      |> Keyword.put(:on_thinking, &send(parent, {:assistant_thinking_delta, &1}))
      |> Keyword.put(:on_tool_started, &send(parent, {:tool_started, &1}))
      |> Keyword.put(:on_tool_finished, &send(parent, {:tool_finished, &1}))

    {ask_opts, state}
  end

  defp ask_options(state, parent, ref, session_id) do
    ask_opts =
      state.llm_opts
      |> Keyword.put(:session_id, session_id)
      |> Keyword.put(:stream_owner, {parent, ref})
      |> Keyword.put(:on_tool_started, &send(parent, {:tool_started, &1}))
      |> Keyword.put(:on_tool_finished, &send(parent, {:tool_finished, &1}))

    {ask_opts, state}
  end

  defp cancel_prompt(%{prompt_task: nil} = state), do: state

  defp cancel_prompt(state) do
    if is_pid(state.active_agent) and Process.alive?(state.active_agent) do
      _ = Exy.Agent.Coding.cancel(state.active_agent, reason: :user_cancelled)
      GenServer.stop(state.active_agent, :normal, 100)
    end

    if is_pid(state.prompt_task) and Process.alive?(state.prompt_task) do
      Process.exit(state.prompt_task, :kill)
    end

    state
    |> Map.merge(%{prompt_task: nil, prompt_ref: nil, active_agent: nil})
    |> emit(Event.new(:assistant_aborted, state.state.session_id, %{reason: "cancelled"}))
  end

  defp record_prompt_result(state, {:ok, response}) do
    state = record_successful_response(state, response)

    case Usage.from_response(response) do
      nil -> state
      usage -> emit(state, Event.new(:usage_updated, state.state.session_id, usage))
    end
  end

  defp record_prompt_result(state, {:error, reason}) do
    state =
      emit(
        state,
        Event.new(:assistant_aborted, state.state.session_id, %{reason: inspect(reason)})
      )

    emit(
      state,
      Event.new(:assistant_message_added, state.state.session_id, %{error: inspect(reason)})
    )
  end

  defp record_successful_response(
         %{state: %{streaming_message: %{text: text}}} = state,
         _response
       )
       when is_binary(text) and text != "" do
    emit(state, Event.new(:assistant_stream_finished, state.state.session_id, %{}))
  end

  defp record_successful_response(state, response) do
    emit(state, Event.new(:assistant_message_added, state.state.session_id, %{result: response}))
  end

  defp emit(state, event) do
    Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {__MODULE__, :event, event}) end)
    dispatch_plugin_event(state.state, event)
    %{state | state: Reducer.apply_event(state.state, event)}
  end

  defp dispatch_plugin_event(ui_state, event) do
    dispatch_plugin_lifecycle(event.type, event.data, ui_state, plugin_event?(event.type))
  end

  defp dispatch_plugin_lifecycle(type, data, ui_state, enabled? \\ true) do
    if enabled? and Process.whereis(Exy.Plugin.Manager) do
      context = %{session_id: ui_state.session_id, cwd: ui_state.cwd, model: ui_state.model}
      Task.start(fn -> Exy.Plugin.Manager.dispatch(type, data, context) end)
    end

    :ok
  end

  defp plugin_event?(:plugin_status_updated), do: false
  defp plugin_event?(:plugin_status_cleared), do: false
  defp plugin_event?(:plugin_widget_updated), do: false
  defp plugin_event?(:plugin_widget_cleared), do: false
  defp plugin_event?(:notification_added), do: false
  defp plugin_event?(:notification_expired), do: false
  defp plugin_event?(_type), do: true

  defp normalize_command(%Command{} = command), do: command
  defp normalize_command(type) when is_atom(type), do: Command.new(type)

  defp normalize_command({type, data}) when is_atom(type) and is_map(data),
    do: Command.new(type, data)

  defp run_slash_command("clear", _args, state) do
    emit(state, Event.new(:messages_cleared, state.state.session_id, %{}))
  end

  defp run_slash_command("compact", _args, state) do
    run_compaction(state)
  end

  defp run_slash_command(command, _args, state) do
    case slash_selector(command, state.state) do
      nil ->
        emit(
          state,
          Event.new(:notification_added, state.state.session_id, %{
            level: :warning,
            text: "unknown command: /#{command}"
          })
        )

      selector ->
        emit(state, Event.new(:selector_opened, state.state.session_id, selector))
    end
  end

  defp run_selector_action(%{selector: :model_selector, item: model}, state)
       when is_binary(model) do
    emit(state, Event.new(:model_selected, state.state.session_id, %{model: model}))
  end

  defp run_selector_action(%{selector: :session_selector, item: session_id}, state)
       when is_binary(session_id) do
    emit(state, Event.new(:session_selected, state.state.session_id, %{session_id: session_id}))
  end

  defp run_selector_action(%{selector: :skill_selector, item: skill}, state)
       when is_binary(skill) do
    emit(
      state,
      Event.new(:notification_added, state.state.session_id, %{
        level: :info,
        text: "selected skill: #{skill}"
      })
    )
  end

  defp run_selector_action(%{selector: :command_palette, item: command}, state)
       when is_binary(command) do
    run_slash_command(command, "", state)
  end

  defp run_selector_action(_data, state), do: state

  defp run_compaction(state) do
    session_id = state.state.session_id
    state = emit(state, Event.new(:status_changed, session_id, %{status: :compacting}))

    case Exy.Context.compact(session_id: session_id) do
      {:ok, %{summary: summary}} ->
        emit(state, Event.new(:context_compaction_finished, session_id, %{summary: summary}))

      {:error, reason} ->
        emit(
          state,
          Event.new(:notification_added, session_id, %{level: :error, text: inspect(reason)})
        )
    end
  end

  defp slash_selector("model", ui_state) do
    %{kind: :model_selector, title: "Model", items: [ui_state.model], selected: 0, limit: 8}
  end

  defp slash_selector("session", _ui_state) do
    items = Exy.Session.list() |> Enum.map(& &1.id)
    %{kind: :session_selector, title: "Session", items: items, selected: 0, limit: 8}
  end

  defp slash_selector("skill", _ui_state) do
    items = Exy.Skill.list() |> Enum.map(& &1.name)
    %{kind: :skill_selector, title: "Skill", items: items, selected: 0, limit: 8}
  end

  defp slash_selector("commands", _ui_state) do
    %{
      kind: :command_palette,
      title: "Commands",
      items: ["model", "session", "skill", "clear", "compact"],
      selected: 0,
      limit: 8
    }
  end

  defp slash_selector(_command, _ui_state), do: nil

  defp maybe_register_ui_bus(session_id) do
    if Process.whereis(Exy.UI.Bus), do: Exy.UI.Bus.register(session_id, self()), else: :ok
  end

  defp safe_ask(ask_fun, text, opts) do
    ask_fun.(text, opts)
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  catch
    kind, reason -> {:error, Exception.format(kind, reason, __STACKTRACE__)}
  end

  defp default_ask(text, opts) do
    agent_opts = Keyword.take(opts, [:model, :session_id])
    ask_opts = opts |> agent_ask_opts() |> Keyword.delete(:stream_owner)

    with {:ok, agent} <- Exy.start_link(agent_opts) do
      notify_stream_owner(opts[:stream_owner], agent)

      try do
        Exy.ask(agent, text, Keyword.put_new(ask_opts, :timeout, 120_000))
      after
        if Process.alive?(agent), do: GenServer.stop(agent)
      end
    end
  end

  defp notify_stream_owner({owner, ref}, agent) when is_pid(owner) and is_reference(ref) do
    send(owner, {:active_agent, ref, agent})
  end

  defp notify_stream_owner(_owner, _agent), do: :ok
end
