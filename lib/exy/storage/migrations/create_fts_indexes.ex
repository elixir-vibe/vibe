defmodule Exy.Storage.Migrations.CreateFTSIndexes do
  @moduledoc "Internal implementation module."
  use Ecto.Migration

  import Exy.Storage.FTS.Migration

  def up do
    create_fts5(:ui_events_fts,
      unindexed: [:session_id, :event_id, :seq, :role, :at],
      indexed: [:text],
      tokenize: "unicode61"
    )

    create_fts5(:memories_fts,
      unindexed: [:memory_id, :scope_type, :scope_id, :inserted_at],
      indexed: [:text],
      tokenize: "unicode61"
    )
  end

  def down do
    drop_fts5(:ui_events_fts)
    drop_fts5(:memories_fts)
  end
end
