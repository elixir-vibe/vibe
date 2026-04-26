defmodule Exy.Agent.MemoryTest do
  use ExUnit.Case, async: false

  test "stores runtime memory per agent id" do
    agent_id = "agent-#{System.unique_integer([:positive])}"
    other_agent_id = agent_id <> "-other"

    assert :ok = Exy.Agent.Memory.put(agent_id, :plan, "inspect docs")
    assert {:ok, "inspect docs"} = Exy.Agent.Memory.get(agent_id, :plan)
    assert :error = Exy.Agent.Memory.get(other_agent_id, :plan)
    assert %{plan: "inspect docs"} = Exy.Agent.Memory.list(agent_id)
    assert :ok = Exy.Agent.Memory.clear(agent_id)
    assert %{} = Exy.Agent.Memory.list(agent_id)
  end
end
