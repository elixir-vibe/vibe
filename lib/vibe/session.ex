defmodule Vibe.Session do
  @moduledoc """
  Server-owned Vibe session process.

  A session owns semantic UI state, accepts UI-neutral commands, emits events to
  subscribers, and delegates model work through an injectable ask function. TUI
  and LiveView clients attach to the same session model instead of owning the
  conversation themselves.

  Sessions are supervised and can be looked up, attached, detached, searched,
  and restored from durable SQLite-backed event history.
  """

  use GenServer

  alias Vibe.Model.{Effort, Switcher}
  alias Vibe.Session.PromptLifecycle
  alias Vibe.Storage.Search
  alias Vibe.UI.{Command, Event, PluginBridge, Reducer, SlashCommands, State, ToolEvent}

  require Vibe.Debug

  @type ask_fun :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @notification_ttl_ms 8_000

  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    id = Keyword.get_lazy(opts, :session_id, &Vibe.Session.Store.new_id/0)
    opts = Keyword.put(opts, :session_id, id)

    DynamicSupervisor.start_child(
      Vibe.SessionSupervisor,
      %{
        id: {__MODULE__, id},
        start:
          {__MODULE__, :start_link, [Keyword.put(opts, :name, Vibe.Session.Listing.via(id))]},
        restart: :temporary
      }
    )
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(id) do
    case Registry.lookup(Vibe.Registry, {:session, id}) do
      [{pid, _value}] -> {:ok, pid}
      [] -> Vibe.Session.Listing.start_stored(id)
    end
  end

  @spec active_count() :: non_neg_integer()
  def active_count, do: Vibe.Session.Listing.active_count()

  @spec list(keyword()) :: [map()]
  def list(opts \\ []), do: Vibe.Session.Listing.list(opts)

  @spec search(String.t(), keyword()) :: [Search.Result.t()]
  def search(query, opts \\ []), do: Search.sessions(query, opts)

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

  @spec detach(GenServer.server(), pid()) :: :ok
  def detach(server, pid \\ self()) when is_pid(pid), do: GenServer.call(server, {:detach, pid})

  @spec state(GenServer.server()) :: State.t()
  def state(server), do: GenServer.call(server, :state)

  @spec dispatch(GenServer.server(), Command.t() | atom() | {atom(), map()}) :: :ok
  def dispatch(server, command),
    do: GenServer.call(server, {:dispatch, normalize_command(command)})

  @spec emit_event(GenServer.server(), Event.t()) :: :ok
  def emit_event(server, %Event{} = event), do: GenServer.call(server, {:emit_event, event})

  @spec emit_transient_event(GenServer.server(), Event.t()) :: :ok
  def emit_transient_event(server, %Event{} = event),
    do: GenServer.call(server, {:emit_transient_event, event})

  @spec lock(GenServer.server(), String.t(), pid()) :: :ok
  def lock(server, job_id, owner \\ self()) when is_binary(job_id) and is_pid(owner),
    do: GenServer.call(server, {:lock, job_id, owner})

  @spec unlock(GenServer.server(), String.t()) :: :ok
  def unlock(server, job_id) when is_binary(job_id), do: GenServer.call(server, {:unlock, job_id})

  @doc """
  Returns prompt options passed to the agent after session-only keys are removed.
  """
  @spec agent_ask_opts(keyword()) :: keyword()
  def agent_ask_opts(opts), do: Keyword.drop(opts, [:model, :effort])

  @impl true
  def init(opts) do
    persist? = Keyword.get(opts, :persist?, true)
    restoring? = Keyword.get(opts, :restoring?, false)
    {state, event_seq, events_tail} = restore_state(State.new(opts), persist?, restoring?)

    if persist?,
      do:
        Vibe.Session.Store.ensure_session(state.session_id, DateTime.utc_now(),
          cwd: state.cwd,
          model: state.model
        )

    maybe_register_in_registry(state.session_id)
    maybe_register_ui_bus(state.session_id)
    broadcast_session_change(state.session_id)
    unless restoring?, do: PluginBridge.dispatch_lifecycle(:session_started, %{}, state)

    {:ok,
     %{
       state: state,
       ask_fun: Keyword.get(opts, :ask_fun, &Vibe.UI.PromptRunner.default_ask/2),
       llm_opts: PromptLifecycle.llm_opts(opts),
       streaming?: Keyword.get(opts, :streaming?, not Keyword.has_key?(opts, :ask_fun)),
       locked_by_job: Keyword.get(opts, :locked_by_job),
       lock_owner: Keyword.get(opts, :lock_owner),
       subscribers: %{},
       prompt_task: nil,
       prompt_ref: nil,
       active_agent: nil,
       event_seq: event_seq,
       events_tail: events_tail,
       persist?: persist?,
       persistence_failed?: false,
       last_user_prompt: nil
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
    replay_events(state, replay_after, pid)
    {:reply, {:ok, state.state, state.event_seq}, state}
  end

  def handle_call({:detach, pid}, _from, state) do
    {removed, subscribers} =
      Enum.split_with(state.subscribers, fn {_ref, subscriber} -> subscriber == pid end)

    Enum.each(removed, fn {ref, _subscriber} -> Process.demonitor(ref, [:flush]) end)
    {:reply, :ok, %{state | subscribers: Map.new(subscribers)}}
  end

  def handle_call({:dispatch, %Command{} = command}, {caller, _tag}, state) do
    state =
      Vibe.Telemetry.span([:vibe, :session, :command], command_metadata(command, state), fn ->
        handle_command(command, state, caller)
      end)

    {:reply, :ok, state}
  end

  def handle_call({:lock, job_id, owner}, _from, state) do
    {:reply, :ok, %{state | locked_by_job: job_id, lock_owner: owner}}
  end

  def handle_call({:unlock, job_id}, _from, %{locked_by_job: job_id} = state) do
    {:reply, :ok, %{state | locked_by_job: nil, lock_owner: nil}}
  end

  def handle_call({:unlock, _job_id}, _from, state), do: {:reply, :ok, state}

  def handle_call({:emit_event, %Event{} = event}, _from, state) do
    {:reply, :ok, emit(state, event)}
  end

  def handle_call({:emit_transient_event, %Event{} = event}, _from, state) do
    {:reply, :ok, emit(state, event, persist?: false)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, ref)}}
  end

  def handle_info({:notification_expired, id}, state) do
    event = Event.new(:notification_expired, state.state.session_id, %{id: id})
    {:noreply, emit(state, event, persist?: false)}
  end

  def handle_info({:prompt_result, ref, result}, %{prompt_ref: ref} = state) do
    state = %{state | prompt_task: nil, prompt_ref: nil, active_agent: nil}
    state = PromptLifecycle.record_result(state, result, &emit/2)
    {:noreply, state}
  end

  def handle_info({:prompt_result, _ref, _result}, state), do: {:noreply, state}

  def handle_info({:active_agent, ref, agent}, %{prompt_ref: ref} = state) when is_pid(agent) do
    {:noreply, %{state | active_agent: agent}}
  end

  def handle_info({:active_agent, _ref, _agent}, state), do: {:noreply, state}

  def handle_info({:assistant_delta, text}, state) do
    Vibe.Debug.run do
      Vibe.Agent.Streaming.Trace.record(:ui_assistant_delta, %{
        session_id: state.state.session_id,
        text: text
      })
    end

    {:noreply, emit(state, Event.new(:assistant_delta, state.state.session_id, %{text: text}))}
  end

  def handle_info({:assistant_thinking_delta, text}, state) do
    {:noreply,
     emit(state, Event.new(:assistant_thinking_delta, state.state.session_id, %{text: text}))}
  end

  def handle_info({:tool_preparing, %ToolEvent{} = data}, state) do
    {:noreply, emit(state, Event.new(:tool_updated, state.state.session_id, data))}
  end

  def handle_info({:tool_started, %ToolEvent{} = data}, state) do
    {:noreply, emit(state, Event.new(:tool_started, state.state.session_id, data))}
  end

  def handle_info({:tool_finished, %ToolEvent{} = data}, state) do
    {:noreply, emit(state, Event.new(:tool_finished, state.state.session_id, data))}
  end

  defp handle_command(command, state, caller) do
    if locked?(state, caller) and command.type == :submit_prompt do
      locked_notice(state)
    else
      handle_command(command, state)
    end
  end

  defp handle_command(%Command{type: :submit_prompt, data: %{content: content}}, state)
       when is_list(content) do
    PromptLifecycle.submit(state, content, &emit/2)
  end

  defp handle_command(%Command{type: :submit_prompt, data: %{text: text}}, state)
       when is_binary(text) do
    PromptLifecycle.submit(state, text, &emit/2)
  end

  defp handle_command(%Command{type: :cancel_stream}, state) do
    PromptLifecycle.cancel(state, &emit/2)
  end

  defp handle_command(%Command{type: :toggle_truncation}, state) do
    emit(state, Event.new(:truncation_toggled, state.state.session_id, %{}))
  end

  defp handle_command(%Command{type: :open_model_selector}, state) do
    open_model_selector(state)
  end

  defp handle_command(%Command{type: :open_effort_selector}, state) do
    open_effort_selector(state)
  end

  defp handle_command(%Command{type: :cycle_model, data: data}, state) do
    direction = Map.get(data, :direction, :forward)

    case Switcher.cycle_model(state.state.model, direction) do
      {:ok, model} ->
        emit(state, Event.new(:model_selected, state.state.session_id, %{model: model}))

      {:error, :one_model} ->
        notify(state, "Only one model available")
    end
  end

  defp handle_command(%Command{type: :select_model, data: %{model: model}}, state)
       when is_binary(model) do
    emit(state, Event.new(:model_selected, state.state.session_id, %{model: model}))
  end

  defp handle_command(%Command{type: :cycle_effort}, state) do
    effort = Switcher.cycle_effort(state.state.effort, state.state.model)

    emit(state, Event.new(:effort_selected, state.state.session_id, %{effort: effort}))
  end

  defp handle_command(%Command{type: :select_effort, data: %{effort: effort}}, state)
       when effort in [:off, :minimal, :low, :medium, :high, :xhigh] do
    emit(state, Event.new(:effort_selected, state.state.session_id, %{effort: effort}))
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

  defp locked?(%{locked_by_job: nil}, _caller), do: false
  defp locked?(%{lock_owner: owner}, caller), do: owner != caller

  defp locked_notice(state) do
    emit(
      state,
      Event.new(:notification_added, state.state.session_id, %{
        level: :warning,
        text: "This subagent session is read-only until the job finishes."
      })
    )
  end

  defp emit(state, event, opts \\ []) do
    event = prepare_transient_event(event)
    event_seq = state.event_seq + 1
    persist? = Keyword.get(opts, :persist?, persist_event?(state, event))

    {events, persistence_failed?} =
      events_with_persistence_status(state, event, event_seq, persist?)

    schedule_notification_expiry(event)

    Enum.each(events, fn {_seq, event} ->
      Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {__MODULE__, :event, event}) end)
    end)

    ui_state =
      Enum.reduce(events, state.state, fn {_seq, event}, ui_state ->
        Reducer.apply_event(ui_state, event)
      end)

    Enum.each(events, fn {_seq, event} -> PluginBridge.dispatch(ui_state, event) end)
    if session_list_relevant?(event), do: broadcast_session_change(state.state.session_id)

    %{
      state
      | state: ui_state,
        event_seq: event_seq + length(events) - 1,
        events_tail:
          Enum.reduce(events, state.events_tail, fn {seq, event}, tail ->
            remember_event(tail, seq, event)
          end),
        persistence_failed?: persistence_failed?
    }
  end

  defp prepare_transient_event(%Event{type: :notification_added} = event) do
    data = Map.put_new(event.data, :id, event.id)
    %{event | data: data}
  end

  defp prepare_transient_event(event), do: event

  defp persist_event?(_state, %Event{type: type})
       when type in [:notification_added, :notification_expired],
       do: false

  defp persist_event?(state, _event), do: state.persist?

  defp schedule_notification_expiry(%Event{type: :notification_added, data: data}) do
    ttl_ms = Map.get(data, :ttl_ms, @notification_ttl_ms)

    if is_integer(ttl_ms) and ttl_ms > 0 do
      Process.send_after(self(), {:notification_expired, Map.fetch!(data, :id)}, ttl_ms)
    end

    :ok
  end

  defp schedule_notification_expiry(_event), do: :ok

  defp events_with_persistence_status(state, event, event_seq, false) do
    {[{event_seq, event}], state.persistence_failed?}
  end

  defp events_with_persistence_status(state, event, event_seq, true) do
    case Vibe.Session.Store.append_ui_event(event, event_seq) do
      :ok ->
        {[{event_seq, event}], state.persistence_failed?}

      {:error, reason} ->
        require Logger
        Logger.error("Vibe session persistence failed: #{inspect(reason)}")

        failure_event =
          Event.new(:notification_added, state.state.session_id, %{
            level: :error,
            text: "Session persistence failed: #{inspect(reason)}"
          })

        events =
          if state.persistence_failed?,
            do: [{event_seq, event}],
            else: [{event_seq, event}, {event_seq + 1, failure_event}]

        {events, true}
    end
  end

  defp command_metadata(%Command{} = command, state) do
    %{
      session_id: state.state.session_id,
      command: command.type,
      status: state.state.status
    }
  end

  defp normalize_command(%Command{} = command), do: command
  defp normalize_command(type) when is_atom(type), do: Command.new(type)

  defp normalize_command({type, data}) when is_atom(type) and is_map(data),
    do: Command.new(type, data)

  defp run_slash_command(command, args, state) do
    case SlashCommands.handle(command, args, state.state) do
      {:events, events} -> Enum.reduce(events, state, &emit(&2, &1))
      {:command, command} -> handle_command(normalize_command(command), state)
      :compact -> run_compaction(state)
      :ignore -> state
    end
  end

  defp run_selector_action(%{selector: :model_selector, item: model}, state)
       when is_binary(model) do
    handle_command(Command.new(:select_model, %{model: model}), state)
  end

  defp run_selector_action(%{selector: :effort_selector, item: effort}, state)
       when is_binary(effort) do
    case Effort.from_string(effort) do
      {:ok, effort} -> handle_command(Command.new(:select_effort, %{effort: effort}), state)
      {:error, {:unknown_effort, value}} -> notify(state, "unknown effort: #{value}")
    end
  end

  defp run_selector_action(data, state) do
    case SlashCommands.selector_action(data, state.state) do
      {:events, events} -> Enum.reduce(events, state, &emit(&2, &1))
      {:command, command} when is_binary(command) -> run_slash_command(command, "", state)
      {:command, command} -> handle_command(normalize_command(command), state)
      :ignore -> state
    end
  end

  defp open_model_selector(state) do
    items = Switcher.model_options(state.state.model)

    selector = %{
      kind: :model_selector,
      title: "Model",
      items: items,
      selected: selected_index(items, state.state.model),
      limit: 8
    }

    emit(state, Event.new(:selector_opened, state.state.session_id, selector))
  end

  defp open_effort_selector(state) do
    items = Enum.map(Switcher.effort_options(state.state.model), &Effort.label/1)

    current = Effort.label(state.state.effort || Effort.default())

    selector = %{
      kind: :effort_selector,
      title: "Effort",
      items: items,
      selected: selected_index(items, current),
      limit: 6
    }

    emit(state, Event.new(:selector_opened, state.state.session_id, selector))
  end

  defp selected_index(items, current) do
    case Enum.find_index(items, &(&1 == current)) do
      nil -> 0
      index -> index
    end
  end

  defp notify(state, text) do
    emit(
      state,
      Event.new(:notification_added, state.state.session_id, %{level: :info, text: text})
    )
  end

  defp run_compaction(state) do
    session_id = state.state.session_id
    tokens_before = estimate_tokens(state.state.messages)

    state =
      emit(
        state,
        Event.new(:context_compaction_started, session_id, %{tokens_before: tokens_before})
      )

    case Vibe.Context.compact(session_id: session_id) do
      {:ok, %{summary: summary}} ->
        emit(state, Event.new(:context_compaction_finished, session_id, %{summary: summary}))

      {:error, reason} ->
        emit(
          state,
          Event.new(:context_compaction_failed, session_id, %{reason: inspect(reason)})
        )
    end
  end

  defp estimate_tokens(messages) do
    messages
    |> Enum.map_join("\n", fn message ->
      message
      |> Map.take([:text, :result, :error])
      |> Map.values()
      |> Enum.find(& &1)
      |> token_text()
    end)
    |> String.length()
    |> div(4)
  end

  defp token_text(nil), do: ""
  defp token_text(value) when is_binary(value), do: value
  defp token_text(value), do: inspect(value, limit: 20)

  defp restore_state(state, false, _restoring?), do: {state, 0, []}

  defp restore_state(state, true, restoring?) do
    events = Vibe.Session.Store.ui_events(state.session_id)

    ui_state =
      state
      |> Reducer.apply_events(Enum.map(events, fn {_seq, event} -> event end))
      |> finalize_restored_state(restoring?)

    event_seq = events |> last_event({0, nil}) |> elem(0)
    {ui_state, event_seq, Enum.take(events, -200)}
  end

  defp finalize_restored_state(state, false), do: state

  defp finalize_restored_state(%{status: :working} = state, true) do
    has_active_stream? = not is_nil(state.streaming_message)

    has_running_tool? =
      Enum.any?(state.pending_tools, fn {_id, tool} -> Map.get(tool, :status) == :running end)

    if has_active_stream? or has_running_tool?, do: state, else: %{state | status: :idle}
  end

  defp finalize_restored_state(state, true), do: state

  defp replay_events(state, replay_after, pid) do
    events =
      if durable_replay?(state, replay_after) do
        Vibe.Session.Store.ui_events_after(state.state.session_id, replay_after)
      else
        Enum.filter(state.events_tail, fn {seq, _event} -> seq > replay_after end)
      end

    Enum.each(events, fn {_seq, event} -> send(pid, {__MODULE__, :event, event}) end)
  end

  defp durable_replay?(%{persist?: false}, _replay_after), do: false
  defp durable_replay?(%{events_tail: []}, _replay_after), do: false

  defp durable_replay?(%{events_tail: [{oldest_seq, _event} | _events]}, replay_after),
    do: replay_after < oldest_seq

  defp remember_event(events, seq, event),
    do: events |> Vibe.Support.Lists.append({seq, event}) |> Enum.take(-200)

  defp last_event([], default), do: default
  defp last_event([event], _default), do: event
  defp last_event([_event | events], default), do: last_event(events, default)

  defp maybe_register_in_registry(session_id) do
    case Registry.lookup(Vibe.Registry, {:session, session_id}) do
      [{pid, _}] when pid == self() -> :ok
      [{_other, _}] -> :ok
      [] -> Registry.register(Vibe.Registry, {:session, session_id}, nil)
    end

    :ok
  end

  defp maybe_register_ui_bus(session_id) do
    if Process.whereis(Vibe.UI.Bus), do: Vibe.UI.Bus.register(session_id, self()), else: :ok
  end

  @session_list_events [
    :user_message_added,
    :assistant_message_added,
    :assistant_stream_finished,
    :assistant_aborted,
    :status_changed,
    :model_selected,
    :usage_updated
  ]

  defp session_list_relevant?(%{type: type}) when type in @session_list_events, do: true
  defp session_list_relevant?(_event), do: false

  @sessions_topic "vibe:sessions"

  @doc false
  def sessions_topic, do: @sessions_topic

  defp broadcast_session_change(session_id) do
    Phoenix.PubSub.broadcast(Vibe.PubSub, @sessions_topic, {:session_changed, session_id})
  rescue
    _error -> :ok
  end
end
