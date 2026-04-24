defmodule Exy.Actions.EvalTest do
  use ExUnit.Case, async: true

  test "schema uses JSONSpec directly" do
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{"code" => "1 + 1"})
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{code: "1 + 1"})
  end
end
