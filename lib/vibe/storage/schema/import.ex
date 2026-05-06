defmodule Vibe.Storage.Schema.Import do
  @moduledoc "Ecto schema: imported session metadata."
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "imports" do
    field(:source, :string)
    field(:imported_at, :utc_datetime_usec)
    field(:metadata, :map, default: %{})
  end
end
