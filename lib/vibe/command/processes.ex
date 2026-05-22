defmodule Vibe.Command.Processes do
  @moduledoc false
  use GenServer

  @table Vibe.Command.Streaming

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    create_table()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:ensure_table, _from, state) do
    create_table()
    {:reply, :ok, state}
  end

  @spec track(String.t() | nil, pid()) :: :ok
  def track(session_id, pid) when is_binary(session_id) and is_pid(pid) do
    ensure_table()
    :ets.insert(@table, {{session_id, pid}, true})
    :ok
  end

  def track(_session_id, _pid), do: :ok

  @spec untrack(String.t() | nil, pid()) :: :ok
  def untrack(session_id, pid) when is_binary(session_id) and is_pid(pid) do
    ensure_table()
    :ets.delete(@table, {session_id, pid})
    :ok
  end

  def untrack(_session_id, _pid), do: :ok

  @spec cancel_session(String.t()) :: :ok
  def cancel_session(session_id) when is_binary(session_id) do
    ensure_table()

    session_id
    |> tracked_pids()
    |> Enum.map(&cancel_action(session_id, &1))
    |> Enum.each(&run_cancel_action/1)

    :ok
  end

  defp cancel_action(session_id, pid),
    do: %{session_id: session_id, pid: pid, cancel?: cancellable_pid?(pid)}

  defp run_cancel_action(%{pid: pid, cancel?: true} = action) do
    GenServer.call(pid, :cancel)
    untrack(action.session_id, pid)
  end

  defp run_cancel_action(%{pid: pid, cancel?: false} = action) do
    untrack(action.session_id, pid)
  end

  defp tracked_pids(session_id) do
    @table
    |> :ets.match({{session_id, :"$1"}, :_})
    |> List.flatten()
  end

  defp cancellable_pid?(pid), do: is_pid(pid) and Process.alive?(pid)

  defp ensure_table do
    case :ets.info(@table) do
      :undefined -> ensure_owned_table()
      _info -> @table
    end
  end

  defp ensure_owned_table do
    if Process.whereis(__MODULE__) do
      :ok = GenServer.call(__MODULE__, :ensure_table)
      @table
    else
      raise "#{inspect(__MODULE__)} is not running"
    end
  end

  defp create_table do
    case :ets.info(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, read_concurrency: true])
      _info -> @table
    end
  end
end
