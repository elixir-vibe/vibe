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

  test "plugin traces and prefers ordered ReAct runtime deltas over derived LLM delta signals", %{
    agent: agent,
    agent_id: agent_id
  } do
    trace_dir = trace_dir()
    test_pid = self()
    Exy.Agent.Streaming.register(agent, on_result: &send(test_pid, {:content, &1}))

    runtime_signal = %{
      type: "ai.react.runtime_event",
      data: %{
        event: %{
          kind: :llm_delta,
          llm_call_id: "call-1",
          data: %{chunk_type: :content, delta: "program"}
        }
      }
    }

    duplicate_signal = %{
      type: "ai.llm.delta",
      data: %{call_id: "call-1", chunk_type: :content, delta: "program"}
    }

    assert {:ok, :continue} =
             Exy.Agent.Streaming.Plugin.handle_signal(runtime_signal, %{agent: %{id: agent_id}})

    assert {:ok, :continue} =
             Exy.Agent.Streaming.Plugin.handle_signal(duplicate_signal, %{agent: %{id: agent_id}})

    assert_receive {:content, "program"}
    refute_receive {:content, "program"}, 50

    assert %{
             runtime_text: "program",
             derived_text: "",
             ui_text: "",
             final_text: ""
           } = Exy.Agent.Streaming.Trace.compare!(trace_dir)

    assert Enum.any?(Exy.Agent.Streaming.Trace.read!(trace_dir), &(&1["suppressed?"] == true))
  after
    Exy.Agent.Streaming.unregister(agent)
    System.delete_env("EXY_STREAM_TRACE_DIR")
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

  test "unregister tolerates an exited agent" do
    pid = spawn(fn -> :ok end)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, reason}
    assert reason in [:normal, :noproc]

    assert :ok = Exy.Agent.Streaming.unregister(pid)
  end

  test "plugin forwards streamed tool params", %{agent: agent, agent_id: agent_id} do
    test_pid = self()

    Exy.Agent.Streaming.register(agent,
      on_tool_preparing: &send(test_pid, {:tool_preparing, &1})
    )

    signal = %{
      type: "ai.tool.params",
      data: %{call_id: "call-1", tool_name: "eval", arguments: %{code: "IO."}}
    }

    assert {:ok, :continue} =
             Exy.Agent.Streaming.Plugin.handle_signal(signal, %{agent: %{id: agent_id}})

    assert_receive {:tool_preparing,
                    %Exy.UI.ToolEvent{
                      id: "call-1",
                      name: "eval",
                      args: %{code: "IO."},
                      status: :preparing,
                      phase: :preparing
                    }}
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
      data: %{call_id: "call-1", tool_name: "eval", arguments: %{code: "1 + 1"}}
    }

    finished = %{
      type: "ai.tool.result",
      data: %{
        call_id: "call-1",
        tool_name: "eval",
        result: {:ok, %{output: "2", output_format: :inspect}, []}
      }
    }

    assert {:ok, :continue} = Exy.Agent.Streaming.Plugin.handle_signal(started, context)
    assert {:ok, :continue} = Exy.Agent.Streaming.Plugin.handle_signal(finished, context)

    assert_receive {:tool_started,
                    %Exy.UI.ToolEvent{id: "call-1", name: "eval", args: %{code: "1 + 1"}}}

    assert_receive {:tool_finished,
                    %Exy.UI.ToolEvent{
                      id: "call-1",
                      name: "eval",
                      output: "2",
                      output_format: :inspect,
                      status: :ok
                    }}
  after
    Exy.Agent.Streaming.unregister(agent)
  end

  test "plugin forwards failed tool results", %{agent: agent, agent_id: agent_id} do
    test_pid = self()
    Exy.Agent.Streaming.register(agent, on_tool_finished: &send(test_pid, {:tool_finished, &1}))

    signal = %{
      type: "ai.tool.result",
      data: %{call_id: "call-1", tool_name: "eval", result: {:error, "boom", []}}
    }

    assert {:ok, :continue} =
             Exy.Agent.Streaming.Plugin.handle_signal(signal, %{agent: %{id: agent_id}})

    assert_receive {:tool_finished,
                    %Exy.UI.ToolEvent{
                      id: "call-1",
                      name: "eval",
                      output: %{error: "boom"},
                      status: :error
                    }}
  after
    Exy.Agent.Streaming.unregister(agent)
  end

  defp trace_dir do
    dir = Path.join(System.tmp_dir!(), "exy-stream-trace-#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)
    System.put_env("EXY_STREAM_TRACE_DIR", dir)
    dir
  end
end
