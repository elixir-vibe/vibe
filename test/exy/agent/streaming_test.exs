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

  test "plugin forwards tool lifecycle signals", %{agent: agent, agent_id: agent_id} do
    test_pid = self()

    Exy.Agent.Streaming.register(agent,
      on_tool_started: &send(test_pid, {:tool_started, &1}),
      on_tool_finished: &send(test_pid, {:tool_finished, &1})
    )

    context = %{agent: %{id: agent_id}}

    started = %{
      type: "ai.tool.started",
      data: %{call_id: "call-1", tool_name: "elixir_eval", arguments: %{code: "1 + 1"}}
    }

    finished = %{
      type: "ai.tool.result",
      data: %{call_id: "call-1", tool_name: "elixir_eval", result: {:ok, %{output: "2"}, []}}
    }

    assert {:ok, :continue} = Exy.Agent.Streaming.Plugin.handle_signal(started, context)
    assert {:ok, :continue} = Exy.Agent.Streaming.Plugin.handle_signal(finished, context)

    assert_receive {:tool_started, %{id: "call-1", name: "elixir_eval", args: %{code: "1 + 1"}}}

    assert_receive {:tool_finished,
                    %{id: "call-1", name: "elixir_eval", output: "2", status: :ok}}
  after
    Exy.Agent.Streaming.unregister(agent)
  end
end
