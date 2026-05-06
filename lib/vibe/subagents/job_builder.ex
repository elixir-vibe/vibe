defmodule Vibe.Subagents.JobBuilder do
  @moduledoc "Subagent job configuration builder."
  alias Vibe.Subagents.JobInfo

  @spec new(String.t(), keyword()) :: {:ok, JobInfo.t()} | {:error, term()}
  def new(task, opts) do
    role = Keyword.get(opts, :role)

    with :ok <- validate_role(role, opts) do
      id = Keyword.get_lazy(opts, :id, &new_id/0)
      child_session_id = Keyword.get_lazy(opts, :child_session_id, &Vibe.Session.Store.new_id/0)
      model = Keyword.get(opts, :model) || Vibe.Agent.Profile.model_for(role: role)

      {:ok,
       %JobInfo{
         id: id,
         task: task,
         role: role,
         model: model,
         parent_session_id: Keyword.get(opts, :parent_session_id),
         child_session_id: child_session_id,
         status: :running,
         started_at: DateTime.utc_now()
       }}
    end
  end

  @spec reconstruct() :: %{String.t() => JobInfo.t()}
  def reconstruct do
    Registry.select(Vibe.Registry, [
      {{{:subagent, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Map.new(fn {id, pid, meta} ->
      job = reconstruct_job(id, pid, Map.new(meta))
      Process.monitor(pid)
      {id, job}
    end)
  end

  defp reconstruct_job(id, pid, meta) do
    %JobInfo{
      id: id,
      task: Map.get(meta, :task, ""),
      role: Map.get(meta, :role),
      model: Map.get(meta, :model) || Vibe.Agent.Profile.model_for(role: Map.get(meta, :role)),
      parent_session_id: Map.get(meta, :parent_session_id),
      child_session_id: Map.get(meta, :child_session_id),
      status: :running,
      started_at: started_at(meta),
      pid: pid
    }
  end

  defp validate_role(nil, _opts), do: :ok

  defp validate_role(role, opts) do
    cond do
      Keyword.has_key?(opts, :model) or Keyword.has_key?(opts, :system) -> :ok
      match?({:ok, _profile}, Vibe.Agent.Profile.role(role)) -> :ok
      true -> {:error, {:unknown_role, role}}
    end
  end

  defp started_at(%{started_at: millis}) when is_integer(millis),
    do: DateTime.from_unix!(millis, :millisecond)

  defp started_at(_meta), do: DateTime.utc_now()

  defp new_id do
    "sg-" <> Base.url_encode64(:crypto.strong_rand_bytes(5), padding: false)
  end
end
