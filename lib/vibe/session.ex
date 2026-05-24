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

  alias Vibe.Event
  alias Vibe.Session.Command.Intent, as: Command
  alias Vibe.Session.{EvalLifecycle, PromptLifecycle}
  alias Vibe.Storage.Search
  alias Vibe.Tool.Event, as: ToolEvent
  alias Vibe.UI.{PluginBridge, State}

  require Vibe.Debug

  @type ask_fun :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    id = Keyword.get_lazy(opts, :session_id, &Vibe.Session.Store.new_id/0)
    opts = Keyword.put(opts, :session_id, id)

    child_opts = Keyword.put(opts, :name, Vibe.Session.Registry.via(id))

    child_spec =
      Supervisor.child_spec({__MODULE__, child_opts}, id: {__MODULE__, id}, restart: :temporary)

    DynamicSupervisor.start_child(Vibe.SessionSupervisor, child_spec)
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(id) do
    case Registry.lookup(Vibe.Registry, {:session, id}) do
      [{pid, _value}] -> {:ok, pid}
      [] -> start_stored(id)
    end
  end

  @doc "Intentional facade for the public Vibe API boundary."
  @spec active_count() :: non_neg_integer()
  defdelegate active_count, to: Vibe.Session.Listing

  @doc "Intentional facade for the public Vibe API boundary."
  @spec list(keyword()) :: [map()]
  defdelegate list(opts \\ []), to: Vibe.Session.Listing

  @spec search(String.t(), keyword()) :: [Search.Result.t()]
  def search(query, opts \\ []), do: Search.sessions(query, opts)

  defp start_stored(id) do
    if stored?(id),
      do: start(session_id: id, restoring?: true),
      else: {:error, :not_found}
  end

  defp stored?(id) do
    not is_nil(Vibe.Session.Store.info(id)) or File.exists?(Vibe.Session.Store.path(id)) or
      File.exists?(Vibe.Session.Store.events_path(id))
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

  @spec detach(GenServer.server(), pid()) :: :ok
  def detach(server, pid \\ self()) when is_pid(pid), do: GenServer.call(server, {:detach, pid})

  @spec state(GenServer.server()) :: State.t()
  def state(server), do: GenServer.call(server, :state)

  @spec dispatch(GenServer.server(), Command.t() | atom() | {atom(), map()}) :: :ok
  def dispatch(server, command),
    do:
      GenServer.call(server, {:dispatch, Vibe.Session.CommandHandler.normalize(command)}, 30_000)

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
    custom_ask? = Keyword.has_key?(opts, :ask_fun)
    opts = Keyword.put_new_lazy(opts, :runtime_alerts, &active_runtime_alerts/0)

    {state, event_seq, events_tail} =
      Vibe.Session.Replay.restore_state(State.new(opts), persist?, restoring?)

    state = maybe_load_goal(state, persist?)

    if persist?,
      do:
        Vibe.Session.Store.ensure_session(state.session_id, DateTime.utc_now(),
          cwd: state.cwd,
          model: state.model
        )

    maybe_register_in_registry(state.session_id)
    maybe_register_event_bus(state.session_id)
    Vibe.Session.EventEmitter.broadcast_session_change(state.session_id)
    unless restoring?, do: PluginBridge.dispatch_lifecycle(:session_started, %{}, state)

    {:ok,
     %{
       state: state,
       ask_fun: Keyword.get(opts, :ask_fun, &Vibe.UI.PromptRunner.default_ask/2),
       llm_opts: PromptLifecycle.llm_opts(opts),
       streaming?: Keyword.get(opts, :streaming?, not custom_ask?),
       context?: Keyword.get(opts, :context?, true),
       context_async?: Keyword.get(opts, :context_async?, not custom_ask?),
       locked_by_job: Keyword.get(opts, :locked_by_job),
       lock_owner: Keyword.get(opts, :lock_owner),
       subscribers: %{},
       prompt_task: nil,
       prompt_ref: nil,
       active_agent: nil,
       eval_tasks: %{},
       event_seq: event_seq,
       events_tail: events_tail,
       persist?: persist?,
       persistence_failed?: false,
       last_user_prompt: nil,
       goal_continuation?: Keyword.get(opts, :goal_continuation?, not custom_ask?),
       goal_continuation_timer: nil
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
    Vibe.Session.Replay.replay_events(state, replay_after, pid)
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
      Vibe.Telemetry.span(
        [:vibe, :session, :command],
        Vibe.Session.CommandHandler.metadata(command, state),
        fn ->
          handle_command(command, state, caller)
        end
      )

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
    event =
      Event.new(
        :notification_expired,
        state.state.session_id,
        Vibe.Event.Notification.expired(id)
      )

    {:noreply, emit(state, event, persist?: false)}
  end

  def handle_info({:prompt_result, ref, result}, %{prompt_ref: ref} = state) do
    state = %{state | prompt_task: nil, prompt_ref: nil, active_agent: nil}
    state = PromptLifecycle.record_result(state, result, &emit/2)
    {:noreply, maybe_schedule_goal_continuation(state)}
  end

  def handle_info(:continue_goal_if_idle, state) do
    state = %{state | goal_continuation_timer: nil}

    if continue_goal?(state) do
      state =
        emit(
          state,
          Event.new(
            :goal_continuation_started,
            state.state.session_id,
            Vibe.Event.Goal.continuation_started()
          )
        )

      {:noreply, PromptLifecycle.submit(state, "Continue the active goal.", &emit/2)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:prompt_result, _ref, _result}, state), do: {:noreply, state}

  def handle_info({:active_agent, ref, agent}, %{prompt_ref: ref} = state) when is_pid(agent) do
    {:noreply, %{state | active_agent: agent}}
  end

  def handle_info({:active_agent, _ref, _agent}, state), do: {:noreply, state}

  def handle_info({:assistant_delta, text}, state) do
    Vibe.Debug.run do
      Vibe.Agent.Streaming.Trace.record(:surface_assistant_delta, %{
        session_id: state.state.session_id,
        text: text
      })
    end

    {:noreply,
     emit(
       state,
       Event.new(:assistant_delta, state.state.session_id, Vibe.Event.AssistantStream.delta(text))
     )}
  end

  def handle_info({:assistant_thinking_delta, text}, state) do
    {:noreply,
     emit(
       state,
       Event.new(
         :assistant_thinking_delta,
         state.state.session_id,
         Vibe.Event.AssistantStream.thinking_delta(text)
       )
     )}
  end

  def handle_info({:tool_preparing, %ToolEvent{} = data}, state) do
    {:noreply,
     emit(state, Event.new(:tool_updated, state.state.session_id, Vibe.Event.Tool.updated(data)))}
  end

  def handle_info({:tool_started, %ToolEvent{} = data}, state) do
    {:noreply,
     emit(state, Event.new(:tool_started, state.state.session_id, Vibe.Event.Tool.started(data)))}
  end

  def handle_info({:tool_finished, %ToolEvent{} = data}, state) do
    {:noreply,
     emit(
       state,
       Event.new(:tool_finished, state.state.session_id, Vibe.Event.Tool.finished(data))
     )}
  end

  def handle_info({:eval_expression_finished, id, duration_ms, result}, state) do
    {:noreply, EvalLifecycle.record_result(state, id, duration_ms, result, &emit/2)}
  end

  defp handle_command(command, state, caller) do
    Vibe.Session.CommandHandler.handle(command, state, caller, command_handler_context())
  end

  defp command_handler_context do
    %{
      emit: &emit/2,
      emit_opts: &emit/3
    }
  end

  defp emit(state, event), do: emit(state, event, [])

  defp emit(state, event, opts) do
    Vibe.Session.EventEmitter.emit(state, event, Keyword.validate!(opts, [:persist?]))
  end

  defp maybe_schedule_goal_continuation(%{goal_continuation?: false} = state), do: state

  defp maybe_schedule_goal_continuation(%{goal_continuation_timer: timer} = state)
       when not is_nil(timer),
       do: state

  defp maybe_schedule_goal_continuation(state) do
    if Vibe.Goals.Goal.active?(Vibe.Goals.get(state.state.session_id)) do
      timer = Process.send_after(self(), :continue_goal_if_idle, 100)
      %{state | goal_continuation_timer: timer}
    else
      state
    end
  end

  defp continue_goal?(state) do
    is_nil(state.prompt_task) and Vibe.Goals.Goal.active?(Vibe.Goals.get(state.state.session_id))
  end

  defp active_runtime_alerts do
    Vibe.SystemAlarms.Active.map()
  catch
    :exit, _reason -> %{}
  end

  defp maybe_load_goal(state, false), do: state
  defp maybe_load_goal(state, true), do: %{state | goal: Vibe.Goals.get(state.session_id)}

  defp maybe_register_in_registry(session_id) do
    case Registry.lookup(Vibe.Registry, {:session, session_id}) do
      [{pid, _}] when pid == self() -> :ok
      [{_other, _}] -> :ok
      [] -> Registry.register(Vibe.Registry, {:session, session_id}, nil)
    end

    :ok
  end

  defp maybe_register_event_bus(session_id) do
    if Process.whereis(Vibe.Event.Bus), do: Vibe.Event.Bus.register(session_id, self()), else: :ok
  end

  @doc false
  def sessions_topic, do: "vibe:sessions"
end
