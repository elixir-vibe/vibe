defmodule Exy.Storage.Schema.MemoryFTS do
  @moduledoc "Internal implementation module."
  use Ecto.Schema

  @primary_key false
  schema "memories_fts" do
    field(:memory_id, :string)
    field(:scope_type, :string)
    field(:scope_id, :string)
    field(:inserted_at, :string)
    field(:text, :string)
  end
end
