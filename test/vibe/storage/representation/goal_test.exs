defmodule Vibe.Storage.Representation.GoalTest do
  use ExUnit.Case, async: true

  alias Vibe.Goals.Goal
  alias Vibe.Storage.Persistable
  alias Vibe.Storage.Representation.Goal, as: StoredGoal
  alias Vibe.Storage.Restorable

  test "persists and restores goals through storage protocols" do
    goal = %Goal{
      session_id: "session-1",
      goal_id: "goal-1",
      objective: "Ship it",
      status: :active,
      token_budget: 100,
      tokens_used: 10,
      time_used_seconds: 5,
      created_at: ~U[2026-05-20 12:00:00Z],
      updated_at: ~U[2026-05-20 12:01:00Z]
    }

    stored = Persistable.persist(goal)

    assert %StoredGoal{status: :active} = stored
    assert Restorable.restore(stored) == goal
  end
end
