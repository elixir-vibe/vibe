defmodule Exy.Storage.Schema.TelemetryEvent do
  @moduledoc "Ecto schema: local telemetry event storage."
  use Ecto.Schema

  schema "telemetry_events" do
    field(:name, :string)
    field(:at, :utc_datetime_usec)
    field(:measurements, :map)
    field(:metadata, :map)
  end
end
