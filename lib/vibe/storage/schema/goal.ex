defmodule Vibe.Storage.Schema.Goal do
  @moduledoc "Ecto schema: persisted session goals."
  use Ecto.Schema

  @primary_key {:session_id, :string, autogenerate: false}
  schema "goals" do
    field(:goal_id, :string)
    field(:objective, :string)
    field(:status, :string)
    field(:token_budget, :integer)
    field(:tokens_used, :integer, default: 0)
    field(:time_used_seconds, :integer, default: 0)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end
end
