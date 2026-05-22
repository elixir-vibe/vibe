defmodule Vibe.Storage.Schema.SessionEventFTS do
  @moduledoc "Ecto schema: FTS5 virtual table for session event search."
  use Ecto.Schema

  @primary_key false
  schema "session_events_fts" do
    field(:session_id, :string)
    field(:event_id, :string)
    field(:seq, :integer)
    field(:role, :string)
    field(:at, :string)
    field(:text, :string)
  end
end
