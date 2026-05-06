defmodule Vibe.EvalTest do
  use ExUnit.Case, async: true

  test "one-off eval captures result and io" do
    assert {:ok, result} = Vibe.Eval.once(~s|IO.puts("hello"); 1 + 2|)
    assert result.output =~ "hello"
    assert result.output =~ "3"
  end

  test "stateful eval requires a session id" do
    assert {:error, error} = Vibe.Eval.run("1 + 1", [])
    assert error =~ "session_id is required"
  end

  test "cancel interrupts a running stateful eval" do
    session_id = "eval-cancel-#{System.unique_integer([:positive])}"
    parent = self()

    task =
      Task.async(fn ->
        send(parent, :eval_started)
        Vibe.Eval.run("Process.sleep(5_000)", session_id: session_id, timeout: 10_000)
      end)

    assert_receive :eval_started, 500
    assert_eval_registered(session_id)
    assert :ok = Vibe.Eval.cancel(session_id)

    assert {:error, error} = Task.await(task, 5_000)
    assert error =~ "evaluation process exited"
  end

  test "command result exposes exit_status" do
    assert {:ok, result} =
             Vibe.Eval.once(~S|Cmd.run(["bash", "-lc", "exit 0"]).exit_status|,
               timeout: 5_000
             )

    assert result.output =~ "0"
  end

  test "eval errors preserve captured IO" do
    assert {:error, error} = Vibe.Eval.once(~S|IO.puts("before boom"); raise "boom"|)

    assert error =~ "before boom"
    assert error =~ "boom"
  end

  test "cancel interrupts a command running inside eval" do
    session_id = "eval-command-cancel-#{System.unique_integer([:positive])}"
    parent = self()

    task =
      Task.async(fn ->
        send(parent, :eval_started)

        Vibe.Eval.run(~S|Cmd.run(["bash", "-lc", "sleep 5"], timeout: 10_000)|,
          session_id: session_id,
          timeout: 10_000
        )
      end)

    assert_receive :eval_started, 500
    assert_eval_registered(session_id)
    assert_command_tracked(session_id)
    assert :ok = Vibe.Eval.cancel(session_id)

    assert {:error, error} = Task.await(task, 5_000)
    assert error =~ "evaluation process exited"
  end

  defp assert_eval_registered(session_id, attempts \\ 50)

  defp assert_eval_registered(_session_id, 0), do: flunk("eval process was not registered")

  defp assert_eval_registered(session_id, attempts) do
    case Registry.lookup(Vibe.Registry, {:eval, session_id}) do
      [{pid, _value}] when is_pid(pid) ->
        :ok

      [] ->
        Process.sleep(20)
        assert_eval_registered(session_id, attempts - 1)
    end
  end

  defp assert_command_tracked(session_id, attempts \\ 250)

  defp assert_command_tracked(_session_id, 0), do: flunk("eval command was not tracked")

  defp assert_command_tracked(session_id, attempts) do
    if :ets.whereis(Vibe.Command.Streaming) != :undefined and
         :ets.match(Vibe.Command.Streaming, {{session_id, :"$1"}, :_}) != [] do
      :ok
    else
      Process.sleep(20)
      assert_command_tracked(session_id, attempts - 1)
    end
  end
end
