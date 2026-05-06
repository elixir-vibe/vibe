defmodule Vibe.Agent.MemoryTest do
  use ExUnit.Case, async: false

  test "stores runtime memory per agent id" do
    agent_id = "agent-#{System.unique_integer([:positive])}"
    other_agent_id = agent_id <> "-other"

    assert :ok = Vibe.Agent.Memory.put(agent_id, :plan, "inspect docs")
    assert {:ok, "inspect docs"} = Vibe.Agent.Memory.get(agent_id, :plan)
    assert :error = Vibe.Agent.Memory.get(other_agent_id, :plan)
    assert %{plan: "inspect docs"} = Vibe.Agent.Memory.list(agent_id)
    assert :ok = Vibe.Agent.Memory.clear(agent_id)
    assert %{} = Vibe.Agent.Memory.list(agent_id)
  end
end
