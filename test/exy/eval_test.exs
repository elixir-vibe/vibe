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
end
