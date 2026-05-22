defmodule Vibe.CommandTest do
  use ExUnit.Case, async: true

  alias Vibe.Command
  alias Vibe.Command.Result

  @command_timeout_ms 5_000

  test "run waits for command result and writes full output log" do
    result = Command.run(["sh", "-c", "printf hello"], timeout: @command_timeout_ms)

    assert %Result{status: :ok, exit_status: 0, output: "hello"} = result
    assert File.read!(result.output_path) == "hello"
    assert result.duration_ms >= 0
  end

  test "run returns a truncated tail with a full output pointer" do
    result =
      Command.run(
        ["sh", "-c", "i=1; while [ $i -le 3000 ]; do echo $i; i=$((i+1)); done"],
        timeout: @command_timeout_ms
      )

    assert %Result{status: :ok, exit_status: 0} = result
    assert result.output =~ "3000"
    refute result.output =~ "\n1\n"
    assert result.output =~ "[Showing lines"
    assert result.output =~ "Full output: #{result.output_path}"
    assert File.read!(result.output_path) =~ "1\n2\n3"
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
    assert_output(job, "ready")

    assert Command.output(job) =~ "ready"
    assert %Result{status: :running} = Command.status(job)
    assert %Result{status: :cancelled} = Command.cancel(job)
  end

  test "output supports explicit byte windows" do
    assert {:ok, job} = Command.start(["sh", "-c", "printf abcdef"])
    assert %Result{status: :ok} = Command.await(job, @command_timeout_ms)

    assert Command.output(job, bytes: 3) == "abc"
    assert Command.output(job, tail_bytes: 3) == "def"
  end

  test "process tracking table is owned by supervised process tracker" do
    assert :ets.info(Vibe.Command.Streaming, :owner) == Process.whereis(Vibe.Command.Processes)
  end

  test "Cmd alias is available in eval" do
    code = "Cmd.run([\"sh\", \"-c\", \"printf ok\"], timeout: #{@command_timeout_ms}).output"
    assert {:ok, result} = Vibe.Eval.run(code, session_id: "cmd-alias-test")

    assert result.output =~ "ok"
  end

  test "Cmd.run streams output into the running eval tool" do
    session_id = "cmd-stream-test-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    :ok =
      Vibe.Session.emit_event(
        session,
        Vibe.Event.new(
          :tool_started,
          session_id,
          Vibe.Event.Tool.started(
            Vibe.Tool.Event.started(id: "eval-tool", name: :eval, args: %{code: "Cmd.run(...)"})
          )
        )
      )

    Vibe.Command.Streaming.with_eval_session(session_id, fn ->
      Command.run(["sh", "-c", "printf streamed"], timeout: @command_timeout_ms)
    end)

    assert %{pending_tools: %{"eval-tool" => tool}} = Vibe.Session.state(session)
    assert tool.output =~ "streamed"
    assert tool.status == :running
  end

  test "Cmd results display command output in eval" do
    code = "Cmd.run([\"sh\", \"-c\", \"printf ok\"], timeout: #{@command_timeout_ms})"
    assert {:ok, result} = Vibe.Eval.run(code, session_id: "cmd-result-display-test")

    assert result.output == "ok"
    assert result.format == :text
    assert result.value_type == Vibe.Command.Result
  end

  defp assert_output(job, expected, attempts \\ 20)

  defp assert_output(job, expected, attempts) when attempts > 0 do
    if Command.output(job) =~ expected do
      :ok
    else
      Process.sleep(5)
      assert_output(job, expected, attempts - 1)
    end
  end

  defp assert_output(job, expected, 0), do: assert(Command.output(job) =~ expected)
end
