defmodule Exy.Storage.Schema.UIEvent do
  @moduledoc "Ecto schema: session UI events."
  use Ecto.Schema

  schema "ui_events" do
    field(:session_id, :string)
    field(:seq, :integer)
    field(:event_id, :string)
    field(:type, :string)
    field(:at, :utc_datetime_usec)
    field(:data, :map)
  end
end
