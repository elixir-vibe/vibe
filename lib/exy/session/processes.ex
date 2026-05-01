defmodule Exy.Session.Processes do
  @moduledoc "Internal implementation module."
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec register(pid(), String.t()) :: :ok
  def register(pid, session_id) when is_pid(pid) and is_binary(session_id) do
    GenServer.call(__MODULE__, {:register, pid, session_id})
  end

  @spec session_id(pid()) :: String.t() | nil
  def session_id(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:session_id, pid})
  end

  @impl true
  def init(_opts), do: {:ok, %{sessions: %{}, monitors: %{}}}

  @impl true
  def handle_call({:register, pid, session_id}, _from, state) do
    state = drop_pid(state, pid)
    ref = Process.monitor(pid)

    state = %{
      state
      | sessions: Map.put(state.sessions, pid, session_id),
        monitors: Map.put(state.monitors, ref, pid)
    }

    {:reply, :ok, state}
  end

  def handle_call({:session_id, pid}, _from, state) do
    {:reply, Map.get(state.sessions, pid), state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {pid, monitors} = Map.pop(state.monitors, ref)
    {:noreply, %{state | sessions: Map.delete(state.sessions, pid), monitors: monitors}}
  end

  defp drop_pid(state, pid) do
    case Enum.find(state.monitors, fn {_ref, monitored_pid} -> monitored_pid == pid end) do
      {ref, _pid} ->
        Process.demonitor(ref, [:flush])

        %{
          state
          | sessions: Map.delete(state.sessions, pid),
            monitors: Map.delete(state.monitors, ref)
        }

      nil ->
        state
    end
  end
end
