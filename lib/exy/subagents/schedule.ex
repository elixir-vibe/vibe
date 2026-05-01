defmodule Exy.Subagents.Schedule do
  @moduledoc "Internal implementation module."
  @type t :: %__MODULE__{}

  @enforce_keys [:id, :task]
  defstruct [
    :id,
    :task,
    :role,
    :parent_session_id,
    :at,
    :every_ms,
    :missed,
    :timer_ref,
    :next_run_at,
    opts: []
  ]
end
