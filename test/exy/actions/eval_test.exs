defmodule Exy.Actions.EvalTest do
  use ExUnit.Case, async: false

  test "default timeout leaves long command timeouts to Cmd.run" do
    assert Exy.Actions.Eval.default_timeout_ms() == 86_400_000
  end

  test "schema uses JSONSpec directly" do
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{"code" => "1 + 1"})
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{code: "1 + 1"})
  end

  test "uses session id from tool context for stateful eval" do
    session_id = "action-eval-#{System.unique_integer([:positive])}"
    File.rm(Exy.Session.Store.path(session_id))
    on_exit(fn -> File.rm(Exy.Session.Store.path(session_id)) end)

    assert {:ok, %{output: ~s("query")}} =
             Exy.Actions.Eval.run(%{"code" => ~s(query = "query")}, %{session_id: session_id})

    assert {:ok, %{output: ~s("query docs")}} =
             Exy.Actions.Eval.run(%{"code" => ~s(query <> " docs")}, %{session_id: session_id})
  end

  test "evaluation failures are serializable tool results, not action crashes" do
    session_id = "action-eval-error-#{System.unique_integer([:positive])}"
    File.rm(Exy.Session.Store.path(session_id))
    on_exit(fn -> File.rm(Exy.Session.Store.path(session_id)) end)

    assert {:ok, %{error: error}} =
             Exy.Actions.Eval.run(%{"code" => ~s(raise "intentional")}, %{session_id: session_id})

    assert error =~ "intentional"
    assert Jason.encode!(%{ok: true, result: %{error: error}})
  end
end
