defmodule Exy.UI.Bus do
  @moduledoc """
  Registry-backed access point for UI sessions.

  Plugins and background workers use this module to update UI state without
  knowing whether the UI is rendered by the TUI, LiveView, or tests.
  """

  use GenServer

  alias Exy.UI.{Command, Event, SessionServer}

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
      SessionServer.dispatch(server, command)
    end
  end

  @spec emit(String.t(), atom(), map()) :: :ok | {:error, :not_found}
  def emit(session_id, type, data \\ %{}) when is_atom(type) and is_map(data) do
    with {:ok, server} <- server(session_id) do
      SessionServer.emit_event(server, Event.new(type, session_id, data))
    end
  end

  @spec set_status(String.t(), String.t() | atom(), String.t() | nil) ::
          :ok | {:error, :not_found}
  def set_status(session_id, key, text), do: Exy.Plugin.UI.set_status(session_id, key, text)

  @impl true
  def init(_opts), do: {:ok, %{sessions: %{}, monitors: %{}}}

  @impl true
  def handle_call({:register, session_id, server}, _from, state) do
    ref = Process.monitor(server)
    sessions = Map.put(state.sessions, session_id, server)
    monitors = Map.put(state.monitors, ref, session_id)
    {:reply, :ok, %{state | sessions: sessions, monitors: monitors}}
  end

  def handle_call({:unregister, session_id, server}, _from, state) do
    sessions =
      case Map.get(state.sessions, session_id) do
        ^server -> Map.delete(state.sessions, session_id)
        _ -> state.sessions
      end

    {:reply, :ok, %{state | sessions: sessions}}
  end

  def handle_call({:server, session_id}, _from, state) do
    case Map.fetch(state.sessions, session_id) do
      {:ok, server} -> {:reply, {:ok, server}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {session_id, monitors} = Map.pop(state.monitors, ref)
    sessions = if session_id, do: Map.delete(state.sessions, session_id), else: state.sessions
    {:noreply, %{state | sessions: sessions, monitors: monitors}}
  end
end
