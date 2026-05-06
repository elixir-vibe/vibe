defmodule Vibe.Subagents.JobStore do
  @moduledoc "Persistent subagent job storage."
  import Ecto.Query

  alias Vibe.Storage
  alias Vibe.Storage.Schema.SubagentJob
  alias Vibe.Subagents.JobInfo

  @spec put(JobInfo.t()) :: :ok | {:error, term()}
  def put(%JobInfo{} = job) do
    Storage.ensure!()

    %SubagentJob{}
    |> Map.merge(%{
      id: job.id,
      parent_session_id: job.parent_session_id,
      child_session_id: job.child_session_id,
      task: job.task,
      role: atom_string(job.role),
      model: job.model,
      status: atom_string(job.status),
      result: encode_result(job.result),
      error: job.error,
      started_at: Storage.normalize_datetime(job.started_at),
      finished_at: Storage.normalize_datetime(job.finished_at),
      duration_ms: job.duration_ms
    })
    |> Vibe.Repo.insert(on_conflict: {:replace_all_except, [:id]}, conflict_target: :id)
    |> ok()
  end

  @spec list(keyword()) :: [JobInfo.t()]
  def list(opts \\ []) do
    Storage.ensure!()

    SubagentJob
    |> maybe_filter_parent_session(Keyword.get(opts, :parent_session_id))
    |> order_by([job], desc: job.started_at)
    |> Vibe.Repo.all()
    |> Enum.map(&decode_job/1)
  end

  @spec get(String.t()) :: JobInfo.t() | nil
  def get(id) do
    Storage.ensure!()

    case Vibe.Repo.get(SubagentJob, id) do
      %SubagentJob{} = job -> decode_job(job)
      nil -> nil
    end
  end

  defp maybe_filter_parent_session(query, nil), do: query

  defp maybe_filter_parent_session(query, parent_session_id) when is_binary(parent_session_id) do
    where(query, [job], job.parent_session_id == ^parent_session_id)
  end

  defp decode_job(%SubagentJob{} = job) do
    %JobInfo{
      id: job.id,
      parent_session_id: job.parent_session_id,
      child_session_id: job.child_session_id,
      task: job.task,
      role: job.role,
      model: job.model,
      status: status_atom(job.status),
      result: decode_result(job.result),
      error: job.error,
      started_at: job.started_at,
      finished_at: job.finished_at,
      duration_ms: job.duration_ms
    }
  end

  defp encode_result(nil), do: nil
  defp encode_result(value), do: %{"value" => json_safe(value)}

  defp decode_result(nil), do: nil
  defp decode_result(%{"value" => value}), do: value
  defp decode_result(value), do: value

  defp json_safe(nil), do: nil
  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(value) when is_map(value),
    do: Map.new(value, fn {k, v} -> {to_string(k), json_safe(v)} end)

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value) when is_binary(value) or is_number(value) or is_boolean(value), do: value
  defp json_safe(value), do: inspect(value)

  defp atom_string(nil), do: nil
  defp atom_string(value) when is_atom(value), do: Atom.to_string(value)
  defp atom_string(value), do: to_string(value)

  defp status_atom(nil), do: :running

  defp status_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> :error
  end

  defp ok({:ok, _result}), do: :ok
  defp ok({:error, reason}), do: {:error, reason}
end
