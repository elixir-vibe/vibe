defmodule Vibe.UI.Bus do
  @moduledoc """
  Registry-backed access point for UI sessions.

  Plugins and background workers use this module to update UI state without
  knowing whether the UI is rendered by the TUI, LiveView, or tests.
  """

  use GenServer

  alias Vibe.Session
  alias Vibe.UI.{Command, Event}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec register(String.t(), GenServer.server()) :: :ok
  def register(session_id, server) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:register, session_id, server})
  end

  @spec unregister(String.t(), GenServer.server()) :: :ok
  def unregister(session_id, server),
    do: GenServer.call(__MODULE__, {:unregister, session_id, server})

  @spec server(String.t()) :: {:ok, GenServer.server()} | {:error, :not_found}
  def server(session_id), do: GenServer.call(__MODULE__, {:server, session_id})

  @spec dispatch(String.t(), Command.t() | atom() | {atom(), map()}) :: :ok | {:error, :not_found}
  def dispatch(session_id, command) do
    with {:ok, server} <- server(session_id) do
      Session.dispatch(server, command)
    end
  end

  @spec emit(String.t(), atom(), map()) :: :ok | {:error, :not_found}
  def emit(session_id, type, data \\ %{}) when is_atom(type) and is_map(data) do
    with {:ok, server} <- server(session_id) do
      Session.emit_event(server, Event.new(type, session_id, data))
    end
  end

  @spec emit_all(atom(), map(), keyword()) :: :ok
  def emit_all(type, data \\ %{}, opts \\ []) when is_atom(type) and is_map(data) do
    GenServer.call(__MODULE__, {:emit_all, type, data, Keyword.get(opts, :persist?, false)})
  end

  @spec notify_all(Vibe.UI.Notification.t() | map() | keyword() | String.t(), keyword()) :: :ok
  def notify_all(notification, opts \\ []) do
    notification = Vibe.UI.Notification.new(notification)
    emit_all(:notification_added, Map.from_struct(notification), opts)
  end

  @spec set_status(String.t(), String.t() | atom(), String.t() | nil) ::
          :ok | {:error, :not_found}
  @doc "Intentional facade for the public Vibe API boundary."
  defdelegate set_status(session_id, key, text), to: Vibe.Plugin.UI

  @impl true
  def init(_opts), do: {:ok, %{sessions: %{}, monitors: %{}, session_refs: %{}}}

  @impl true
  def handle_call({:register, session_id, server}, _from, state) do
    state = demonitor_session(state, session_id)
    ref = Process.monitor(server)

    {:reply, :ok,
     %{
       state
       | sessions: Map.put(state.sessions, session_id, server),
         monitors: Map.put(state.monitors, ref, {session_id, server}),
         session_refs: Map.put(state.session_refs, session_id, ref)
     }}
  end

  def handle_call({:unregister, session_id, server}, _from, state) do
    state =
      case Map.get(state.sessions, session_id) do
        ^server -> demonitor_session(state, session_id) |> delete_session(session_id)
        _other -> state
      end

    {:reply, :ok, state}
  end

  def handle_call({:server, session_id}, _from, state) do
    case Map.fetch(state.sessions, session_id) do
      {:ok, server} -> {:reply, {:ok, server}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:emit_all, type, data, persist?}, _from, state) do
    stale_sessions =
      Enum.flat_map(state.sessions, fn {session_id, server} ->
        event = Event.new(type, session_id, data)

        case safe_emit(server, event, persist?) do
          :ok -> []
          :stale -> [session_id]
        end
      end)

    {:reply, :ok, Enum.reduce(stale_sessions, state, &delete_session(&2, &1))}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {{session_id, server}, monitors} ->
        state = %{state | monitors: monitors}

        state =
          if Map.get(state.sessions, session_id) == server do
            delete_session(state, session_id)
          else
            state
          end

        {:noreply, state}

      {nil, _monitors} ->
        {:noreply, state}
    end
  end

  defp safe_emit(server, event, persist?) do
    if Process.alive?(server) do
      if persist?,
        do: Session.emit_event(server, event),
        else: Session.emit_transient_event(server, event)

      :ok
    else
      :stale
    end
  catch
    :exit, _reason -> :stale
  end

  defp demonitor_session(state, session_id) do
    case Map.fetch(state.session_refs, session_id) do
      {:ok, ref} ->
        Process.demonitor(ref, [:flush])

        %{
          state
          | monitors: Map.delete(state.monitors, ref),
            session_refs: Map.delete(state.session_refs, session_id)
        }

      :error ->
        state
    end
  end

  defp delete_session(state, session_id) do
    %{
      state
      | sessions: Map.delete(state.sessions, session_id),
        session_refs: Map.delete(state.session_refs, session_id)
    }
  end
end
