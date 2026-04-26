defmodule Exy.Eval.EvaluatorTest do
  use ExUnit.Case, async: false

  alias Exy.Test.PluginManagerFixtures.APIPlugin

  setup do
    session_id = "eval-#{System.unique_integer([:positive])}"
    File.rm(Exy.Session.Store.path(session_id))
    on_exit(fn -> File.rm(Exy.Session.Store.path(session_id)) end)
    {:ok, session_id: session_id}
  end

  test "keeps Elixir variables and aliases in a per-session evaluator", %{session_id: session_id} do
    assert {:ok, ~s("weather in washington")} =
             Exy.Eval.run(~s(query = "weather in washington"), session_id: session_id)

    assert {:ok, ~s("weather in washington today")} =
             Exy.Eval.run(~s(query <> " today"), session_id: session_id)

    other_session_id = session_id <> "-other"
    File.rm(Exy.Session.Store.path(other_session_id))
    on_exit(fn -> File.rm(Exy.Session.Store.path(other_session_id)) end)

    assert {:error, error} = Exy.Eval.run(~s(query), session_id: other_session_id)
    assert error =~ "cannot compile file"
  end

  test "keeps IEx helpers available", %{session_id: session_id} do
    assert {:ok, output} = Exy.Eval.run("exports(Enum)", session_id: session_id)
    assert output =~ "map"
  end

  test "restores serializable eval state for resumed sessions", %{session_id: session_id} do
    assert {:ok, _output} =
             Exy.Eval.run(~s(alias String, as: S), session_id: session_id)

    assert {:ok, _output} =
             Exy.Eval.run(~s(import String, only: [upcase: 1]), session_id: session_id)

    assert {:ok, _output} =
             Exy.Eval.run(~s(query = "weather in washington"), session_id: session_id)

    stop_evaluator(session_id)

    assert {:ok, ~s("weather in washington tomorrow")} =
             Exy.Eval.run(~s(query <> " tomorrow"), session_id: session_id)

    assert {:ok, ~s("RAIN")} = Exy.Eval.run("S.upcase(\"rain\")", session_id: session_id)
    assert {:ok, ~s("WIND")} = Exy.Eval.run("upcase(\"wind\")", session_id: session_id)
  end

  test "lists, forgets, and resets session eval state", %{session_id: session_id} do
    assert {:ok, _output} = Exy.Eval.run(~s(query = "weather"), session_id: session_id)
    assert {:ok, _output} = Exy.Eval.run(~s(count = 2), session_id: session_id)

    assert {:ok, bindings} = Exy.Eval.bindings(session_id)

    assert %{name: :query, type: :binary, preview: ~s("weather")} =
             Enum.find(bindings, &(&1.name == :query))

    assert %{name: :count, type: :integer, bytes: bytes} =
             Enum.find(bindings, &(&1.name == :count))

    assert bytes > 0

    assert :ok = Exy.Eval.forget(session_id, [:query])
    assert {:error, error} = Exy.Eval.run(~s(query), session_id: session_id)
    assert error =~ "cannot compile file"
    assert {:ok, "2"} = Exy.Eval.run(~s(count), session_id: session_id)

    stop_evaluator(session_id)
    assert {:error, error} = Exy.Eval.run(~s(query), session_id: session_id)
    assert error =~ "cannot compile file"
    assert {:ok, "2"} = Exy.Eval.run(~s(count), session_id: session_id)

    assert :ok = Exy.Eval.reset(session_id)
    assert {:ok, []} = Exy.Eval.bindings(session_id)
    assert {:error, error} = Exy.Eval.run(~s(count), session_id: session_id)
    assert error =~ "cannot compile file"
  end

  test "preloads plugin API aliases into session evaluators", %{session_id: session_id} do
    assert :ok = Exy.Plugin.Manager.load(APIPlugin, session_id: session_id)

    assert {:ok, output} = Exy.Eval.run("Search.remember(\"query\")", session_id: session_id)
    assert output == ~s({:remembered, "query"})

    assert :ok = Exy.Plugin.Manager.unload(APIPlugin)
  end

  defp stop_evaluator(session_id) do
    with [{pid, _value}] <- Registry.lookup(Exy.Registry, {:eval, session_id}) do
      DynamicSupervisor.terminate_child(Exy.Eval.Supervisor, pid)
    end
  end
end
