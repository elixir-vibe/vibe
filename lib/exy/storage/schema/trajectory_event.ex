defmodule Exy.Storage.Schema.TrajectoryEvent do
  @moduledoc false

  use Ecto.Schema

  schema "trajectory_events" do
    field(:session_id, :string)
    field(:event_id, :string)
    field(:type, :string)
    field(:at, :utc_datetime_usec)
    field(:data, :map)
  end
end
