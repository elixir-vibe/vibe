defmodule Vibe.TUI.App do
  @moduledoc """
  Minimal terminal app coordinator.

  This module keeps terminal mechanics out of semantic UI state. It accepts key
  events and resize events, delegates editing to `Vibe.UI.EditorServer`, and
  dispatches semantic commands to `Vibe.Session`.
  """

  use GenServer

  alias Vibe.Session
  alias Vibe.TUI.InputController

  @active_sessions_tick_ms 1_000
  @server_migration_tick_ms 1_000
  alias Vibe.UI.{Command, EditorServer, Reducer}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec key(GenServer.server(), Vibe.UI.Editor.key()) :: :ok
  def key(server, key), do: GenServer.call(server, {:key, key}, 30_000)

  @spec resize(GenServer.server(), pos_integer(), pos_integer()) :: :ok
  def resize(server, columns, rows), do: GenServer.call(server, {:resize, columns, rows})

  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid \\ self()) when is_pid(pid),
    do: GenServer.call(server, {:subscribe, pid})

  @spec snapshot(GenServer.server()) :: map()
  def snapshot(server), do: GenServer.call(server, :snapshot)

  @impl true
  def init(opts) do
    {:ok, ui} = session_server(opts)
    {:ok, editor} = editor_server(opts)
    {:ok, session_snapshot, _cursor} = Session.attach(ui, self())
    remote_node = Keyword.get(opts, :remote_node)
    active_sessions_timer = Process.send_after(self(), :active_sessions_tick, 0)
    server_migration_timer = maybe_schedule_server_migration(opts)
    server_migration_fun = Keyword.get(opts, :server_migration_fun, &default_server_migration/1)

    {:ok,
     %{
       ui: ui,
       session_snapshot: session_snapshot,
       editor: editor,
       width: Keyword.get(opts, :width, 100),
       height: Keyword.get(opts, :height, 30),
       events: [],
       autocomplete: nil,
       subscribers: %{},
       remote_node: remote_node,
       active_sessions_timer: active_sessions_timer,
       active_sessions_task: nil,
       server_migration_timer: server_migration_timer,
       server_migration_fun: server_migration_fun
     }}
  end

  @impl true
  def handle_call({:key, key}, _from, state) do
    {:reply, :ok, InputController.handle_key(key, state)}
  end

  def handle_call({:resize, columns, rows}, _from, state) do
    {:reply, :ok, %{state | width: columns, height: rows}}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    ref = Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: Map.put(state.subscribers, ref, pid)}}
  end

  def handle_call(:snapshot, _from, state) do
    snapshot = %{
      ui: state.session_snapshot,
      editor: EditorServer.state(state.editor),
      autocomplete: state.autocomplete,
      width: state.width,
      height: state.height,
      events: Enum.reverse(state.events)
    }

    {:reply, snapshot, state}
  end

  @impl true
  def handle_info(:server_migration_tick, state) do
    state = maybe_migrate_to_remote_session(state)
    {:noreply, state}
  end

  def handle_info(:active_sessions_tick, state) do
    state = start_active_sessions_count(state)
    timer = Process.send_after(self(), :active_sessions_tick, @active_sessions_tick_ms)
    {:noreply, %{state | active_sessions_timer: timer}}
  end

  def handle_info({ref, result}, %{active_sessions_task: ref} = state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish_active_sessions_count(%{state | active_sessions_task: nil}, result)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{active_sessions_task: ref} = state) do
    {:noreply, %{state | active_sessions_task: nil, remote_node: nil}}
  end

  def handle_info(
        {Session, :event, %{type: :session_selected, data: %{session_id: session_id}} = event},
        state
      ) do
    notify_subscribers(state, event)

    state =
      case switch_session(state, session_id) do
        {:ok, state} -> state
        {:error, reason} -> notify_session_switch_failed(state, session_id, reason)
      end

    {:noreply, remember_event(state, event)}
  end

  def handle_info({Session, :event, %{type: :session_new_requested} = event}, state) do
    notify_subscribers(state, event)

    state =
      case start_new_session(state) do
        {:ok, state} -> state
        {:error, reason} -> notify_session_switch_failed(state, "new", reason)
      end

    {:noreply, remember_event(state, event)}
  end

  def handle_info({Session, :event, event}, state) do
    notify_subscribers(state, event)
    {:noreply, remember_event(state, event)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, ref)}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp maybe_schedule_server_migration(opts) do
    if Keyword.get(opts, :start_server_async, false),
      do:
        Process.send_after(
          self(),
          :server_migration_tick,
          Keyword.get(opts, :server_migration_delay_ms, 500)
        ),
      else: nil
  end

  defp maybe_migrate_to_remote_session(%{remote_node: node} = state) when not is_nil(node),
    do: state

  defp maybe_migrate_to_remote_session(state) do
    current = state.session_snapshot

    with true <- startup_session?(state),
         {:ok, node, _session_id, remote_session} <- state.server_migration_fun.(current),
         :ok <- Session.detach(state.ui, self()),
         {:ok, session_snapshot, _cursor} <- Session.attach(remote_session, self()) do
      Session.dispatch(
        remote_session,
        Command.new(:notification_added, %{level: :info, text: "attached to background server"})
      )

      %{
        state
        | ui: remote_session,
          session_snapshot: session_snapshot,
          remote_node: node,
          autocomplete: nil,
          server_migration_timer: nil
      }
    else
      false ->
        %{state | server_migration_timer: nil}

      _reason ->
        timer = Process.send_after(self(), :server_migration_tick, @server_migration_tick_ms)
        %{state | server_migration_timer: timer}
    end
  end

  defp startup_session?(state) do
    editor = EditorServer.state(state.editor)

    state.session_snapshot.status == :idle and state.session_snapshot.messages == [] and
      editor.text == ""
  end

  defp default_server_migration(current) do
    with {:ok, node} <- Vibe.Remote.connect(),
         {:ok, %{id: session_id}} <-
           Vibe.Remote.Session.start(
             session_id: current.session_id,
             cwd: current.cwd,
             model: current.model
           ),
         {:ok, remote_session} <- Vibe.Remote.Session.lookup(session_id) do
      {:ok, node, session_id, remote_session}
    end
  end

  defp notify_subscribers(state, event) do
    Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {__MODULE__, :event, event}) end)
  end

  defp switch_session(state, session_id) do
    with {:ok, session} <- lookup_session(state, session_id),
         :ok <- Session.detach(state.ui, self()),
         {:ok, session_snapshot, _cursor} <- Session.attach(session, self()) do
      {:ok, %{state | ui: session, session_snapshot: session_snapshot, autocomplete: nil}}
    end
  end

  defp start_new_session(state) do
    current = state.session_snapshot

    with {:ok, session} <- start_session(state, cwd: current.cwd, model: current.model),
         :ok <- Session.detach(state.ui, self()),
         {:ok, session_snapshot, _cursor} <- Session.attach(session, self()) do
      {:ok, %{state | ui: session, session_snapshot: session_snapshot, autocomplete: nil}}
    end
  end

  defp lookup_session(%{remote_node: node}, session_id) when not is_nil(node) do
    Vibe.Remote.Session.lookup(session_id)
  end

  defp lookup_session(_state, session_id), do: Session.lookup(session_id)

  defp start_session(%{remote_node: node}, opts) when not is_nil(node) do
    with {:ok, %{id: session_id}} <- Vibe.Remote.Session.start(opts) do
      Vibe.Remote.Session.lookup(session_id)
    end
  end

  defp start_session(_state, opts), do: Session.start_link(opts)

  defp notify_session_switch_failed(state, session_id, reason) do
    Session.dispatch(
      state.ui,
      Command.new(:notification_added, %{
        level: :error,
        text: "could not attach #{session_id}: #{inspect(reason)}"
      })
    )

    state
  end

  defp start_active_sessions_count(%{active_sessions_task: ref} = state) when is_reference(ref),
    do: state

  defp start_active_sessions_count(state) do
    task = Task.Supervisor.async_nolink(Vibe.TaskSupervisor, &active_sessions_count/0)
    %{state | active_sessions_task: task.ref}
  end

  defp active_sessions_count do
    with {:ok, node} <- Vibe.Remote.connect(),
         count when is_integer(count) <- Vibe.Remote.Session.active_count() do
      {:ok, node, count}
    else
      reason -> {:error, reason}
    end
  end

  defp finish_active_sessions_count(state, {:ok, node, count}) do
    state = %{state | remote_node: node}
    count = max(count, minimum_visible_session_count(state))

    Session.emit_transient_event(
      state.ui,
      Vibe.Event.new(:active_sessions_updated, state.session_snapshot.session_id, %{count: count})
    )

    state
  end

  defp finish_active_sessions_count(state, _result), do: %{state | remote_node: nil}

  defp minimum_visible_session_count(state) do
    if is_pid(state.ui) and node(state.ui) == state.remote_node, do: 1, else: 0
  end

  defp session_server(opts) do
    case Keyword.fetch(opts, :session_server) do
      {:ok, server} -> {:ok, server}
      :error -> Session.start_link(opts)
    end
  end

  defp editor_server(opts) do
    case Keyword.fetch(opts, :editor_server) do
      {:ok, server} -> {:ok, server}
      :error -> EditorServer.start_link(history: Keyword.get(opts, :history, []))
    end
  end

  defp remember_event(state, event) do
    %{
      state
      | session_snapshot: Reducer.apply_event(state.session_snapshot, event),
        events: [event | state.events]
    }
  end
end
