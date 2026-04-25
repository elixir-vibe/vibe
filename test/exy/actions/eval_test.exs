defmodule Exy.Actions.EvalTest do
  use ExUnit.Case, async: true

  test "schema uses JSONSpec directly" do
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{"code" => "1 + 1"})
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{code: "1 + 1"})
  end

  test "evaluation failures are serializable tool results, not action crashes" do
    assert {:ok, %{error: error}} =
             Exy.Actions.Eval.run(%{"code" => ~s(raise "intentional")}, %{})

    assert error =~ "intentional"
    assert Jason.encode!(%{ok: true, result: %{error: error}})
  end
end
