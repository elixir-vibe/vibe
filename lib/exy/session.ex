defmodule Exy.Session do
  @moduledoc """
  UI-facing session process shared by future TUI and LiveView adapters.

  It owns UI-neutral state, accepts UI-neutral commands, emits events to
  subscribers, and delegates model work through an injectable ask function.
  """

  use GenServer

  alias Exy.LLM.Usage
  alias Exy.UI.{Command, Event, PluginBridge, PromptRunner, Reducer, SlashCommands, State}

  @type ask_fun :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid \\ self()) when is_pid(pid),
    do: GenServer.call(server, {:subscribe, pid})

  @spec attach(GenServer.server(), pid(), keyword()) :: {:ok, State.t(), non_neg_integer()}
  def attach(server, pid \\ self(), opts \\ []) when is_pid(pid),
    do: GenServer.call(server, {:attach, pid, opts})

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
    PluginBridge.dispatch_lifecycle(:session_started, %{}, state)

    {:ok,
     %{
       state: state,
       ask_fun: Keyword.get(opts, :ask_fun, &PromptRunner.default_ask/2),
       llm_opts: Keyword.take(opts, [:model, :system]),
       streaming?: Keyword.get(opts, :streaming?, not Keyword.has_key?(opts, :ask_fun)),
       subscribers: %{},
       prompt_task: nil,
       prompt_ref: nil,
       active_agent: nil,
       event_seq: 0,
       events_tail: []
     }}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    ref = Process.monitor(pid)
    subscribers = Map.put(state.subscribers, ref, pid)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call(:state, _from, state), do: {:reply, state.state, state}

  def handle_call({:attach, pid, opts}, _from, state) do
    ref = Process.monitor(pid)
    state = %{state | subscribers: Map.put(state.subscribers, ref, pid)}
    replay_after = Keyword.get(opts, :after, state.event_seq)
    replay_events(state.events_tail, replay_after, pid)
    {:reply, {:ok, state.state, state.event_seq}, state}
  end

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

    {:ok, task} = PromptRunner.start(ask_fun, text, ask_opts, parent, ref)

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
    PromptRunner.cancel(state.active_agent, state.prompt_task)

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
    event_seq = state.event_seq + 1
    Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {__MODULE__, :event, event}) end)
    ui_state = Reducer.apply_event(state.state, event)
    PluginBridge.dispatch(ui_state, event)

    %{
      state
      | state: ui_state,
        event_seq: event_seq,
        events_tail: remember_event(state.events_tail, event_seq, event)
    }
  end

  defp normalize_command(%Command{} = command), do: command
  defp normalize_command(type) when is_atom(type), do: Command.new(type)

  defp normalize_command({type, data}) when is_atom(type) and is_map(data),
    do: Command.new(type, data)

  defp run_slash_command(command, args, state) do
    case SlashCommands.handle(command, args, state.state) do
      {:events, events} -> Enum.reduce(events, state, &emit(&2, &1))
      :compact -> run_compaction(state)
    end
  end

  defp run_selector_action(data, state) do
    case SlashCommands.selector_action(data, state.state) do
      {:events, events} -> Enum.reduce(events, state, &emit(&2, &1))
      {:command, command} -> run_slash_command(command, "", state)
      :ignore -> state
    end
  end

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

  defp replay_events(events, replay_after, pid) do
    events
    |> Enum.filter(fn {seq, _event} -> seq > replay_after end)
    |> Enum.each(fn {_seq, event} -> send(pid, {__MODULE__, :event, event}) end)
  end

  defp remember_event(events, seq, event),
    do: events |> Exy.Lists.append({seq, event}) |> Enum.take(-200)

  defp maybe_register_ui_bus(session_id) do
    if Process.whereis(Exy.UI.Bus), do: Exy.UI.Bus.register(session_id, self()), else: :ok
  end
end
