defmodule Vibe.Storage.Schema.UIEventFTS do
  @moduledoc "Ecto schema: FTS5 virtual table for UI event search."
  use Ecto.Schema

  @primary_key false
  schema "ui_events_fts" do
    field(:session_id, :string)
    field(:event_id, :string)
    field(:seq, :integer)
    field(:role, :string)
    field(:at, :string)
    field(:text, :string)
  end
end
