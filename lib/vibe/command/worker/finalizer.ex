defmodule Vibe.Command.Worker.Finalizer do
  @moduledoc false

  @spec finish(map(), term(), pid()) :: map()
  def finish(state, result, worker_pid) when is_map(state) and is_pid(worker_pid) do
    Vibe.Command.Processes.untrack(Map.get(state, :eval_session_id), worker_pid)

    state
    |> Map.get(:awaiters, [])
    |> Enum.each(&GenServer.reply(&1, result))

    Map.put(state, :awaiters, [])
  end
end
