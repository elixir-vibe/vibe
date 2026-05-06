defmodule Vibe.SubagentsTest do
  use ExUnit.Case, async: false

  setup do
    Vibe.Session.Store.clear()
    :ok
  end

  test "run under supervision and record trajectory" do
    specs = [
      %{role: :a, goal: "one", run: fn _ -> 1 end},
      %{role: :b, goal: "two", run: fn _ -> 2 end}
    ]

    assert {:ok, results} = Vibe.Subagents.run_many(specs, max_concurrency: 2)
    assert Enum.map(results, & &1.status) == [:ok, :ok]
    assert Enum.map(results, & &1.result) == [1, 2]

    events = Vibe.Session.Store.trajectory()
    assert Enum.count(events, &(&1.type == :subagent_started)) == 2
    assert Enum.count(events, &(&1.type == :subagent_finished)) == 2
  end
end
