defmodule Exy.Storage.Schema.Memory do
  @moduledoc "Internal implementation module."
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "memories" do
    field(:scope_type, :string)
    field(:scope_id, :string)
    field(:text, :string)
    field(:metadata, :map, default: %{})
    field(:inserted_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end
end
