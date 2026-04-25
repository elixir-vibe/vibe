defmodule Exy.Agent.StreamingTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, agent} = Exy.start_link(session_id: "streaming-test")
    {:ok, status} = Jido.AgentServer.status(agent)
    {:ok, agent: agent, agent_id: status.agent_id}
  end

  test "dispatches content and thinking deltas to registered callbacks", %{
    agent: agent,
    agent_id: agent_id
  } do
    test_pid = self()

    Exy.Agent.Streaming.register(agent,
      on_result: &send(test_pid, {:content, &1}),
      on_thinking: &send(test_pid, {:thinking, &1})
    )

    Exy.Agent.Streaming.dispatch(agent_id, %{chunk_type: :content, delta: "hello"})
    Exy.Agent.Streaming.dispatch(agent_id, %{chunk_type: :thinking, delta: "hmm"})

    assert_receive {:content, "hello"}
    assert_receive {:thinking, "hmm"}

    Exy.Agent.Streaming.unregister(agent)
    Exy.Agent.Streaming.dispatch(agent_id, %{chunk_type: :content, delta: "ignored"})

    refute_receive {:content, "ignored"}, 50
  end

  test "plugin forwards Jido LLM delta signals", %{agent: agent, agent_id: agent_id} do
    test_pid = self()
    Exy.Agent.Streaming.register(agent, on_result: &send(test_pid, {:content, &1}))

    signal = %{type: "ai.llm.delta", data: %{chunk_type: :content, delta: "streamed"}}
    context = %{agent: %{id: agent_id}}

    assert {:ok, :continue} = Exy.Agent.Streaming.Plugin.handle_signal(signal, context)
    assert_receive {:content, "streamed"}
  after
    Exy.Agent.Streaming.unregister(agent)
  end
end
