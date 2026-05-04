defmodule Exy.Storage.Schema.SubagentSchedule do
  @moduledoc "Ecto schema: subagent schedule definitions."
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "subagent_schedules" do
    field(:task, :string)
    field(:role, :string)
    field(:parent_session_id, :string)
    field(:run_at, :utc_datetime_usec)
    field(:every_ms, :integer)
    field(:missed, :string, default: "skip")
    field(:opts, :map, default: %{})
    field(:next_run_at, :utc_datetime_usec)
    field(:cancelled_at, :utc_datetime_usec)
    field(:inserted_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end
end
