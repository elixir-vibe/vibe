defmodule Exy.Storage.Schema.SubagentJob do
  @moduledoc "Ecto schema: subagent job records."
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "subagent_jobs" do
    field(:parent_session_id, :string)
    field(:child_session_id, :string)
    field(:task, :string)
    field(:role, :string)
    field(:model, :string)
    field(:status, :string)
    field(:result, :map)
    field(:error, :string)
    field(:started_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)
    field(:duration_ms, :integer)
  end
end
