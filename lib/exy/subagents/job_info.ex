defmodule Exy.Subagents.JobInfo do
  @moduledoc "Internal implementation module."
  @type t :: %__MODULE__{}

  @enforce_keys [:id, :task, :child_session_id]
  defstruct [
    :id,
    :task,
    :role,
    :model,
    :parent_session_id,
    :child_session_id,
    :pid,
    :status,
    :result,
    :error,
    :started_at,
    :finished_at,
    :duration_ms
  ]
end
