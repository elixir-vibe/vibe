defmodule Exy.EvalTest do
  use ExUnit.Case, async: true

  test "one-off eval captures result and io" do
    assert {:ok, result} = Exy.Eval.once(~s|IO.puts("hello"); 1 + 2|)
    assert result.output =~ "hello"
    assert result.output =~ "3"
  end

  test "stateful eval requires a session id" do
    assert {:error, error} = Exy.Eval.run("1 + 1", [])
    assert error =~ "session_id is required"
  end

  test "cancel interrupts a running stateful eval" do
    session_id = "eval-cancel-#{System.unique_integer([:positive])}"
    parent = self()

    task =
      Task.async(fn ->
        send(parent, :eval_started)
        Exy.Eval.run("Process.sleep(5_000)", session_id: session_id, timeout: 10_000)
      end)

    assert_receive :eval_started, 500
    Process.sleep(100)
    assert :ok = Exy.Eval.cancel(session_id)

    assert {:error, error} = Task.await(task, 1_000)
    assert error =~ "evaluation process exited"
  end

  test "command result exposes exit_code alias" do
    assert {:ok, result} =
             Exy.Eval.once(~S|Cmd.run(["bash", "-lc", "exit 0"]).exit_code|,
               timeout: 5_000
             )

    assert result.output =~ "0"
  end

  test "eval errors preserve captured IO" do
    assert {:error, error} = Exy.Eval.once(~S|IO.puts("before boom"); raise "boom"|)

    assert error =~ "before boom"
    assert error =~ "boom"
  end

  test "cancel interrupts a command running inside eval" do
    session_id = "eval-command-cancel-#{System.unique_integer([:positive])}"
    parent = self()

    task =
      Task.async(fn ->
        send(parent, :eval_started)

        Exy.Eval.run(~S|Cmd.run(["bash", "-lc", "sleep 5"], timeout: 10_000)|,
          session_id: session_id,
          timeout: 10_000
        )
      end)

    assert_receive :eval_started, 500
    Process.sleep(200)
    assert :ok = Exy.Eval.cancel(session_id)

    assert {:error, error} = Task.await(task, 1_000)
    assert error =~ "evaluation process exited"
  end
end
