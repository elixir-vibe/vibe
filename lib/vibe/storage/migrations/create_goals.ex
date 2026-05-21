defmodule Vibe.Storage.Migrations.CreateGoals do
  @moduledoc "Migration: persisted session goals."
  use Ecto.Migration

  def change do
    create_if_not_exists table(:goals, primary_key: false) do
      add(:session_id, :text, primary_key: true)
      add(:goal_id, :text, null: false)
      add(:objective, :text, null: false)
      add(:status, :text, null: false)
      add(:token_budget, :integer)
      add(:tokens_used, :integer, null: false, default: 0)
      add(:time_used_seconds, :integer, null: false, default: 0)
      add(:created_at, :utc_datetime_usec, null: false)
      add(:updated_at, :utc_datetime_usec, null: false)
    end

    create_if_not_exists(index(:goals, [:status]))
    create_if_not_exists(index(:goals, [:updated_at]))
  end
end
