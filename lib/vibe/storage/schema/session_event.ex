defmodule Vibe.Storage.Schema.SessionEvent do
  @moduledoc "Ecto schema: session events."
  use Ecto.Schema

  schema "session_events" do
    field(:session_id, :string)
    field(:seq, :integer)
    field(:event_id, :string)
    field(:type, :string)
    field(:at, :utc_datetime_usec)
    field(:data, :map)
  end
end
