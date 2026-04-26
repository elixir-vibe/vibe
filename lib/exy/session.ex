defmodule Exy.Session do
  @moduledoc """
  UI-facing session process shared by future TUI and LiveView adapters.

  It owns UI-neutral state, accepts UI-neutral commands, emits events to
  subscribers, and delegates model work through an injectable ask function.
  """

  use GenServer

  alias Exy.Agent.Usage
  alias Exy.UI.{Command, Event, PluginBridge, PromptRunner, Reducer, SlashCommands, State}

  @type ask_fun :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    id = Keyword.get_lazy(opts, :session_id, &Exy.Session.Store.new_id/0)
    opts = Keyword.put(opts, :session_id, id)

    DynamicSupervisor.start_child(
      Exy.SessionSupervisor,
      %{
        id: {__MODULE__, id},
        start: {__MODULE__, :start_link, [Keyword.put(opts, :name, via(id))]},
        restart: :temporary
      }
    )
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(id) do
    case Registry.lookup(Exy.Registry, {:session, id}) do
      [{pid, _value}] -> {:ok, pid}
      [] -> start_stored(id)
    end
  end

  @spec active_count() :: non_neg_integer()
  def active_count do
    Registry.select(Exy.Registry, [{{{:session, :"$1"}, :"$2", :"$3"}, [], [true]}])
    |> length()
  end

  @spec list() :: [map()]
  def list do
    live =
      Registry.select(Exy.Registry, [
        {{{:session, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}
      ])
      |> Enum.map(&live_info/1)

    stored = Exy.Session.Store.list() |> Enum.map(&Map.put(&1, :live?, false))
    live_ids = MapSet.new(Enum.map(live, & &1.id))

    (live ++ Enum.reject(stored, &MapSet.member?(live_ids, &1.id)))
    |> Enum.sort_by(&updated_at_sort_key/1, :desc)
  end

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

  @spec emit_transient_event(GenServer.server(), Event.t()) :: :ok
  def emit_transient_event(server, %Event{} = event),
    do: GenServer.call(server, {:emit_transient_event, event})

  @doc false
  @spec agent_ask_opts(keyword()) :: keyword()
  def agent_ask_opts(opts), do: Keyword.drop(opts, [:model])

  @impl true
  def init(opts) do
    persist? = Keyword.get(opts, :persist?, true)
    restoring? = Keyword.get(opts, :restoring?, false)
    {state, event_seq, events_tail} = restore_state(State.new(opts), persist?, restoring?)

    maybe_register_ui_bus(state.session_id)
    unless restoring?, do: PluginBridge.dispatch_lifecycle(:session_started, %{}, state)

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
       event_seq: event_seq,
       events_tail: events_tail,
       persist?: persist?,
       persistence_failed?: false
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

  def handle_call({:dispatch, %Command{} = command}, _from, state) do
    {:reply, :ok, handle_command(command, state)}
  end

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

  def handle_info({:tool_started, %Exy.UI.ToolEvent{} = data}, state) do
    {:noreply, emit(state, Event.new(:tool_started, state.state.session_id, data))}
  end

  def handle_info({:tool_finished, %Exy.UI.ToolEvent{} = data}, state) do
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

  defp emit(state, event, opts \\ []) do
    event_seq = state.event_seq + 1
    persist? = Keyword.get(opts, :persist?, state.persist?)

    {events, persistence_failed?} =
      events_with_persistence_status(state, event, event_seq, persist?)

    Enum.each(events, fn {_seq, event} ->
      Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {__MODULE__, :event, event}) end)
    end)

    ui_state =
      Enum.reduce(events, state.state, fn {_seq, event}, ui_state ->
        Reducer.apply_event(ui_state, event)
      end)

    Enum.each(events, fn {_seq, event} -> PluginBridge.dispatch(ui_state, event) end)

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

  defp events_with_persistence_status(state, event, event_seq, false) do
    {[{event_seq, event}], state.persistence_failed?}
  end

  defp events_with_persistence_status(state, event, event_seq, true) do
    case Exy.Session.Store.append_ui_event(event, event_seq) do
      :ok ->
        {[{event_seq, event}], state.persistence_failed?}

      {:error, reason} ->
        require Logger
        Logger.error("Exy session persistence failed: #{inspect(reason)}")

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
    tokens_before = estimate_tokens(state.state.messages)

    state =
      emit(
        state,
        Event.new(:context_compaction_started, session_id, %{tokens_before: tokens_before})
      )

    case Exy.Context.compact(session_id: session_id) do
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
    events = Exy.Session.Store.ui_events(state.session_id)

    ui_state =
      state
      |> Reducer.apply_events(Enum.map(events, fn {_seq, event} -> event end))
      |> finalize_restored_state(restoring?)

    event_seq = events |> List.last({0, nil}) |> elem(0)
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
        Exy.Session.Store.ui_events_after(state.state.session_id, replay_after)
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
    do: events |> Exy.Support.Lists.append({seq, event}) |> Enum.take(-200)

  defp updated_at_sort_key(%{updated_at: %DateTime{} = updated_at}),
    do: DateTime.to_unix(updated_at, :microsecond)

  defp updated_at_sort_key(_session), do: 0

  defp live_info({id, pid}) do
    state = state(pid)
    stored = Exy.Session.Store.info(id) || %{id: id}

    stored
    |> Map.merge(%{
      id: id,
      live?: true,
      status: state.status,
      model: state.model,
      message_count: length(state.messages),
      last_message_preview: state.messages |> List.last() |> Exy.Session.Preview.message(),
      usage: state.usage
    })
  end

  defp start_stored(id) do
    if stored?(id), do: start(session_id: id, restoring?: true), else: {:error, :not_found}
  end

  defp stored?(id) do
    File.exists?(Exy.Session.Store.path(id)) or File.exists?(Exy.Session.Store.ui_events_path(id))
  end

  defp via(id), do: {:via, Registry, {Exy.Registry, {:session, id}}}

  defp maybe_register_ui_bus(session_id) do
    if Process.whereis(Exy.UI.Bus), do: Exy.UI.Bus.register(session_id, self()), else: :ok
  end
end
