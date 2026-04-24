defmodule Exy.SubagentsTest do
  use ExUnit.Case, async: false

  setup do
    Exy.Trajectory.Store.clear()
    :ok
  end

  test "run under supervision and record trajectory" do
    specs = [
      %{role: :a, goal: "one", run: fn _ -> 1 end},
      %{role: :b, goal: "two", run: fn _ -> 2 end}
    ]

    assert {:ok, results} = Exy.Subagents.run_many(specs, max_concurrency: 2)
    assert Enum.map(results, & &1.status) == [:ok, :ok]
    assert Enum.map(results, & &1.result) == [1, 2]

    events = Exy.Trajectory.Store.list()
    assert Enum.count(events, &(&1.type == :subagent_started)) == 2
    assert Enum.count(events, &(&1.type == :subagent_finished)) == 2
  end
end
