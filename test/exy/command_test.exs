defmodule Exy.CommandTest do
  use ExUnit.Case, async: true

  alias Exy.Command
  alias Exy.Command.Result

  @command_timeout_ms 5_000

  test "run waits for command result and writes full output log" do
    result = Command.run(["sh", "-c", "printf hello"], timeout: @command_timeout_ms)

    assert %Result{status: :ok, exit_status: 0, output: "hello"} = result
    assert File.read!(result.output_path) == "hello"
    assert result.duration_ms >= 0
  end

  test "run returns errors with exit status" do
    result = Command.run(["sh", "-c", "echo nope; exit 7"], timeout: @command_timeout_ms)

    assert %Result{status: :error, exit_status: 7} = result
    assert result.output =~ "nope"
  end

  test "run cancels command on await timeout" do
    result = Command.run(["sh", "-c", "sleep 5"], timeout: 20)

    assert %Result{status: :cancelled, exit_status: nil} = result
  end

  test "start exposes status, output, and cancel" do
    assert {:ok, job} = Command.start(["sh", "-c", "echo ready; sleep 5"])
    Process.sleep(100)

    assert Command.output(job) =~ "ready"
    assert %Result{status: :running} = Command.status(job)
    assert %Result{status: :cancelled} = Command.cancel(job)
  end

  test "Cmd alias is available in eval" do
    code = "Cmd.run([\"sh\", \"-c\", \"printf ok\"], timeout: #{@command_timeout_ms}).output"
    assert {:ok, result} = Exy.Eval.run(code, session_id: "cmd-alias-test")

    assert result.output =~ ~s("ok")
  end

  test "Cmd.run streams output into the running eval tool" do
    session_id = "cmd-stream-test-#{System.unique_integer([:positive])}"
    {:ok, session} = Exy.Session.start_link(session_id: session_id, persist?: false)

    :ok =
      Exy.Session.emit_event(
        session,
        Exy.UI.Event.new(
          :tool_started,
          session_id,
          Exy.UI.ToolEvent.started(id: "eval-tool", name: :eval, args: %{code: "Cmd.run(...)"})
        )
      )

    Exy.Command.Streaming.with_eval_session(session_id, fn ->
      Command.run(["sh", "-c", "printf streamed"], timeout: @command_timeout_ms)
    end)

    assert %{pending_tools: %{"eval-tool" => tool}} = Exy.Session.state(session)
    assert tool.output =~ "streamed"
    assert tool.status == :running
  end

  test "Cmd results display command output in eval" do
    code = "Cmd.run([\"sh\", \"-c\", \"printf ok\"], timeout: #{@command_timeout_ms})"
    assert {:ok, result} = Exy.Eval.run(code, session_id: "cmd-result-display-test")

    assert result.output == "ok"
    assert result.format == :text
    assert result.value_type == Exy.Command.Result
  end
end
