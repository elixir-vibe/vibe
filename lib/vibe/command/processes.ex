defmodule Vibe.Command.Processes do
  @moduledoc false

  @table Vibe.Command.Streaming

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

    @table
    |> :ets.match({{session_id, :"$1"}, :_})
    |> List.flatten()
    |> Enum.each(fn pid ->
      if is_pid(pid) and Process.alive?(pid), do: GenServer.call(pid, :cancel)
      untrack(session_id, pid)
    end)

    :ok
  end

  defp ensure_table do
    case :ets.info(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, read_concurrency: true])
      _info -> @table
    end
  end
end
