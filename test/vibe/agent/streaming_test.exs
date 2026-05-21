defmodule Vibe.Agent.StreamingTest do
  use ExUnit.Case, async: false

  alias ReqLLM.StreamChunk
  alias Vibe.Tool.Event, as: ToolEvent

  setup do
    System.delete_env("VIBE_STREAM_TRACE_DIR")
    {:ok, agent} = Vibe.start_link(session_id: "streaming-test")
    {:ok, status} = Jido.AgentServer.status(agent)
    {:ok, agent: agent, agent_id: status.agent_id}
  end

  test "dispatches content and thinking deltas to registered callbacks", %{
    agent: agent,
    agent_id: agent_id
  } do
    test_pid = self()

    Vibe.Agent.Streaming.register(agent,
      on_result: &send(test_pid, {:content, &1}),
      on_thinking: &send(test_pid, {:thinking, &1})
    )

    Vibe.Agent.Streaming.dispatch(agent_id, StreamChunk.text("hello"))
    Vibe.Agent.Streaming.dispatch(agent_id, StreamChunk.thinking("hmm"))

    assert_receive {:content, "hello"}
    assert_receive {:thinking, "hmm"}

    Vibe.Agent.Streaming.unregister(agent)
    Vibe.Agent.Streaming.dispatch(agent_id, StreamChunk.text("ignored"))

    refute_receive {:content, "ignored"}, 10
  end

  test "plugin traces and prefers ordered ReAct runtime deltas over derived LLM delta signals", %{
    agent: agent,
    agent_id: agent_id
  } do
    trace_dir = trace_dir()
    test_pid = self()
    Vibe.Agent.Streaming.register(agent, on_result: &send(test_pid, {:content, &1}))

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
             Vibe.Agent.Streaming.Plugin.handle_signal(runtime_signal, %{agent: %{id: agent_id}})

    assert {:ok, :continue} =
             Vibe.Agent.Streaming.Plugin.handle_signal(duplicate_signal, %{agent: %{id: agent_id}})

    assert_receive {:content, "program"}
    refute_receive {:content, "program"}, 10

    assert %{
             runtime_text: "program",
             runtime_arrival_text: "program",
             derived_text: "",
             ui_text: "",
             final_text: "",
             print_text: ""
           } = Vibe.Agent.Streaming.Trace.compare!(trace_dir)

    assert Enum.any?(Vibe.Agent.Streaming.Trace.read!(trace_dir), &(&1["suppressed?"] == true))
  after
    Vibe.Agent.Streaming.unregister(agent)
    System.delete_env("VIBE_STREAM_TRACE_DIR")
  end

  test "plugin orders ReAct runtime deltas by runtime sequence", %{
    agent: agent,
    agent_id: agent_id
  } do
    test_pid = self()
    Vibe.Agent.Streaming.register(agent, on_result: &send(test_pid, {:content, &1}))

    context = %{agent: %{id: agent_id}}

    signal = fn seq, delta ->
      %{
        type: "ai.react.worker.event",
        data: %{
          event: %{
            seq: seq,
            kind: :llm_delta,
            llm_call_id: "call-ordered",
            data: %{chunk_type: :content, delta: delta}
          }
        }
      }
    end

    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(signal.(1, "a"), context)
    assert_receive {:content, "a"}

    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(signal.(3, "c"), context)
    refute_receive {:content, "c"}, 10

    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(signal.(2, "b"), context)
    assert_receive {:content, "b"}
    assert_receive {:content, "c"}
  after
    Vibe.Agent.Streaming.unregister(agent)
  end

  test "core dispatcher requires ReqLLM stream chunks", %{agent_id: agent_id} do
    assert_raise FunctionClauseError, fn ->
      Code.eval_string(
        "Vibe.Agent.Streaming.dispatch(agent_id, %{chunk_type: :content, delta: \"bad\"})",
        agent_id: agent_id
      )
    end
  end

  test "plugin forwards Jido LLM delta signals", %{agent: agent, agent_id: agent_id} do
    test_pid = self()
    Vibe.Agent.Streaming.register(agent, on_result: &send(test_pid, {:content, &1}))

    signal = %{type: "ai.llm.delta", data: %{chunk_type: :content, delta: "streamed"}}
    context = %{agent: %{id: agent_id}}

    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(signal, context)
    assert_receive {:content, "streamed"}
  after
    Vibe.Agent.Streaming.unregister(agent)
  end

  test "unregister tolerates an exited agent" do
    pid = spawn(fn -> :ok end)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, reason}
    assert reason in [:normal, :noproc]

    assert :ok = Vibe.Agent.Streaming.unregister(pid)
  end

  test "plugin forwards streamed tool params", %{agent: agent, agent_id: agent_id} do
    test_pid = self()

    Vibe.Agent.Streaming.register(agent,
      on_tool_preparing: &send(test_pid, {:tool_preparing, &1})
    )

    signal = %{
      type: "ai.tool.params",
      data: %{call_id: "call-1", tool_name: "eval", arguments: %{code: "IO."}}
    }

    assert {:ok, :continue} =
             Vibe.Agent.Streaming.Plugin.handle_signal(signal, %{agent: %{id: agent_id}})

    assert_receive {:tool_preparing,
                    %ToolEvent{
                      id: "call-1",
                      name: "eval",
                      args: %{code: "IO."},
                      status: :preparing,
                      phase: :preparing
                    }}
  after
    Vibe.Agent.Streaming.unregister(agent)
  end

  test "plugin forwards tool lifecycle signals", %{agent: agent, agent_id: agent_id} do
    test_pid = self()

    Vibe.Agent.Streaming.register(agent,
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

    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(started, context)
    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(finished, context)

    assert_receive {:tool_started, %ToolEvent{id: "call-1", name: "eval", args: %{code: "1 + 1"}}}

    assert_receive {:tool_finished,
                    %ToolEvent{
                      id: "call-1",
                      name: "eval",
                      output: "2",
                      output_format: :inspect,
                      status: :ok
                    }}
  after
    Vibe.Agent.Streaming.unregister(agent)
  end

  test "plugin accepts Jido runtime tool field names", %{agent: agent, agent_id: agent_id} do
    test_pid = self()

    Vibe.Agent.Streaming.register(agent,
      on_tool_started: &send(test_pid, {:tool_started, &1}),
      on_tool_finished: &send(test_pid, {:tool_finished, &1})
    )

    context = %{agent: %{id: agent_id}}

    started = %{
      type: "ai.tool.started",
      data: %{tool_call_id: "call-1", tool_name: "eval", arguments: %{code: "1 + 1"}}
    }

    finished = %{
      type: "ai.tool.result",
      data: %{
        tool_call_id: "call-1",
        tool_name: "eval",
        arguments: %{code: "1 + 1"},
        result: {:ok, %{output: "2", output_format: :inspect}, []}
      }
    }

    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(started, context)
    assert {:ok, :continue} = Vibe.Agent.Streaming.Plugin.handle_signal(finished, context)

    assert_receive {:tool_started, %ToolEvent{id: "call-1", name: "eval", args: %{code: "1 + 1"}}}

    assert_receive {:tool_finished,
                    %ToolEvent{
                      id: "call-1",
                      name: "eval",
                      args: %{code: "1 + 1"},
                      output: "2"
                    }}
  after
    Vibe.Agent.Streaming.unregister(agent)
  end

  test "plugin forwards failed tool results", %{agent: agent, agent_id: agent_id} do
    test_pid = self()
    Vibe.Agent.Streaming.register(agent, on_tool_finished: &send(test_pid, {:tool_finished, &1}))

    signal = %{
      type: "ai.tool.result",
      data: %{call_id: "call-1", tool_name: "eval", result: {:error, "boom", []}}
    }

    assert {:ok, :continue} =
             Vibe.Agent.Streaming.Plugin.handle_signal(signal, %{agent: %{id: agent_id}})

    assert_receive {:tool_finished,
                    %ToolEvent{
                      id: "call-1",
                      name: "eval",
                      output: %{error: "boom"},
                      status: :error
                    }}
  after
    Vibe.Agent.Streaming.unregister(agent)
  end

  defp trace_dir do
    dir = Path.join(System.tmp_dir!(), "vibe-stream-trace-#{System.unique_integer([:positive])}")
    File.rm_rf!(dir)
    System.put_env("VIBE_STREAM_TRACE_DIR", dir)
    dir
  end
end
