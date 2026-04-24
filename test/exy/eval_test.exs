defmodule Exy.EvalTest do
  use ExUnit.Case, async: true

  test "captures result and io" do
    assert {:ok, output} = Exy.Eval.run(~s|IO.puts("hello"); 1 + 2|)
    assert output =~ "hello"
    assert output =~ "3"
  end
end
