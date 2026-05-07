defmodule Vibe.Eval.EvaluatorTest do
  use ExUnit.Case, async: false

  alias Vibe.Test.PluginManagerFixtures.APIPlugin

  setup do
    session_id = "eval-#{System.unique_integer([:positive])}"
    File.rm(Vibe.Session.Store.path(session_id))
    on_exit(fn -> File.rm(Vibe.Session.Store.path(session_id)) end)
    {:ok, session_id: session_id}
  end

  test "keeps Elixir variables and aliases in a per-session evaluator", %{session_id: session_id} do
    assert {:ok, %{output: "weather in washington"}} =
             Vibe.Eval.run(~s(query = "weather in washington"), session_id: session_id)

    assert {:ok, %{output: "weather in washington today"}} =
             Vibe.Eval.run(~s(query <> " today"), session_id: session_id)

    other_session_id = session_id <> "-other"
    File.rm(Vibe.Session.Store.path(other_session_id))
    on_exit(fn -> File.rm(Vibe.Session.Store.path(other_session_id)) end)

    assert {:error, error} = Vibe.Eval.run(~s(query), session_id: other_session_id)
    assert error =~ "cannot compile file"
  end

  test "keeps IEx helpers available", %{session_id: session_id} do
    assert {:ok, result} = Vibe.Eval.run("exports(Enum)", session_id: session_id)
    assert result.output =~ "map"
  end

  test "restores serializable eval state for resumed sessions", %{session_id: session_id} do
    assert {:ok, _output} =
             Vibe.Eval.run(~s(alias String, as: S), session_id: session_id)

    assert {:ok, _output} =
             Vibe.Eval.run(~s(import String, only: [upcase: 1]), session_id: session_id)

    assert {:ok, _output} =
             Vibe.Eval.run(~s(query = "weather in washington"), session_id: session_id)

    stop_evaluator(session_id)

    assert {:ok, %{output: "weather in washington tomorrow"}} =
             Vibe.Eval.run(~s(query <> " tomorrow"), session_id: session_id)

    assert {:ok, %{output: "RAIN"}} =
             Vibe.Eval.run("S.upcase(\"rain\")", session_id: session_id)

    assert {:ok, %{output: "WIND"}} =
             Vibe.Eval.run("upcase(\"wind\")", session_id: session_id)
  end

  test "lists, forgets, and resets session eval state", %{session_id: session_id} do
    assert {:ok, _output} = Vibe.Eval.run(~s(query = "weather"), session_id: session_id)
    assert {:ok, _output} = Vibe.Eval.run(~s(count = 2), session_id: session_id)

    assert {:ok, bindings} = Vibe.Eval.bindings(session_id)

    assert %{name: :query, type: :binary, preview: ~s("weather")} =
             Enum.find(bindings, &(&1.name == :query))

    assert %{name: :count, type: :integer, bytes: bytes} =
             Enum.find(bindings, &(&1.name == :count))

    assert bytes > 0

    assert :ok = Vibe.Eval.forget(session_id, [:query])
    assert {:error, error} = Vibe.Eval.run(~s(query), session_id: session_id)
    assert error =~ "cannot compile file"
    assert {:ok, %{output: "2"}} = Vibe.Eval.run(~s(count), session_id: session_id)

    stop_evaluator(session_id)
    assert {:error, error} = Vibe.Eval.run(~s(query), session_id: session_id)
    assert error =~ "cannot compile file"
    assert {:ok, %{output: "2"}} = Vibe.Eval.run(~s(count), session_id: session_id)

    assert :ok = Vibe.Eval.reset(session_id)
    assert {:ok, []} = Vibe.Eval.bindings(session_id)
    assert {:error, error} = Vibe.Eval.run(~s(count), session_id: session_id)
    assert error =~ "cannot compile file"
  end

  test "string return values display as plain text", %{session_id: session_id} do
    assert {:ok, result} = Vibe.Eval.run(~S|"line 1\nline 2"|, session_id: session_id)

    assert result.output == "line 1\nline 2"
    assert result.format == :text
    refute result.output =~ ~s("line)
    refute result.output =~ ~s(\\n)
  end

  test "captured IO with boring return displays plain IO only", %{session_id: session_id} do
    assert {:ok, result} = Vibe.Eval.run(~S|IO.puts("hello")|, session_id: session_id)

    assert result.output == "hello\n"
    assert result.format == :text
    assert result.parts == [%{output: "hello\n", format: :text}]
  end

  test "captured IO with meaningful return keeps typed output parts", %{session_id: session_id} do
    assert {:ok, result} =
             Vibe.Eval.run(~S|IO.puts("hello"); {:ok, %{answer: 42}}|,
               session_id: session_id
             )

    assert result.output =~ "hello\n"
    assert result.output =~ "{:ok, %{answer: 42}}"
    assert [text, inspect] = result.parts
    assert text == %{output: "hello\n", format: :text}
    assert inspect == %{output: "{:ok, %{answer: 42}}", format: :inspect}
  end

  test "preloads plugin API aliases into session evaluators", %{session_id: session_id} do
    assert :ok = Vibe.Plugin.Manager.load(APIPlugin, session_id: session_id)

    assert {:ok, result} = Vibe.Eval.run("Search.remember(\"query\")", session_id: session_id)
    assert result.output == ~s({:remembered, "query"})

    assert :ok = Vibe.Plugin.Manager.unload(APIPlugin)
  end

  defp stop_evaluator(session_id) do
    with [{pid, _value}] <- Registry.lookup(Vibe.Registry, {:eval, session_id}) do
      DynamicSupervisor.terminate_child(Vibe.Eval.Supervisor, pid)
    end
  end
end
