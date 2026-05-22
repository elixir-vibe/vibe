defmodule Vibe.Command.Worker.FinalizerTest do
  use ExUnit.Case, async: true

  alias Vibe.Command.Worker.Finalizer

  test "replies to awaiters and clears waiter list" do
    caller = self()

    task =
      Task.async(fn ->
        send(caller, :ready)
        GenServer.call(caller, :await_result, 1_000)
      end)

    assert_receive :ready
    assert_receive {:"$gen_call", from, :await_result}

    state = Finalizer.finish(%{awaiters: [from], eval_session_id: nil}, :finished, self())

    assert state.awaiters == []
    assert Task.await(task) == :finished
  end
end
