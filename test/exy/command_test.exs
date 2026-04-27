defmodule Exy.CommandTest do
  use ExUnit.Case, async: true

  alias Exy.Command
  alias Exy.Command.Result

  test "run waits for command result and writes full output log" do
    result = Command.run(["sh", "-c", "printf hello"], timeout: 5_000)

    assert %Result{status: :ok, exit_status: 0, output: "hello"} = result
    assert File.read!(result.output_path) == "hello"
    assert result.duration_ms >= 0
  end

  test "run returns errors with exit status" do
    result = Command.run(["sh", "-c", "echo nope; exit 7"], timeout: 5_000)

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
    code = ~S|Cmd.run(["sh", "-c", "printf ok"], timeout: 5_000).output|
    assert {:ok, output} = Exy.Eval.run(code, session_id: "cmd-alias-test")

    assert output =~ ~s("ok")
  end
end
