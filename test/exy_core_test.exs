defmodule ExyCoreTest do
  use ExUnit.Case, async: false

  setup do
    Exy.Trajectory.Store.clear()
    :ok
  end

  test "eval captures result and io" do
    assert {:ok, output} = Exy.Eval.run(~s|IO.puts("hello"); 1 + 2|)
    assert output =~ "hello"
    assert output =~ "3"
  end

  test "ast search finds Elixir structure" do
    assert {:ok, matches} =
             Exy.AST.run(action: :search, path: "lib/", pattern: "def run(_, _) do _ end")

    assert is_list(matches)
  end

  test "ast diff reports semantic edits" do
    assert {:ok, diff} =
             Exy.AST.run(%{
               action: :diff,
               old_source: "defmodule A do\n  def x, do: 1\nend\n",
               new_source: "defmodule A do\n  def x, do: 2\nend\n"
             })

    assert diff.edits != []
  end

  test "otp runtime info is available" do
    info = Exy.OTP.runtime_info()
    assert info.elixir == System.version()
    assert is_integer(info.process_count)
  end

  test "action schemas use JSONSpec directly" do
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{"code" => "1 + 1"})
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{code: "1 + 1"})
  end

  test "context serialization keeps structured handoff data" do
    events = [
      Exy.Trajectory.new(:user_message, %{prompt: "Build Exy"}),
      Exy.Trajectory.new(:assistant_message, %{result: %{ok: true}}),
      Exy.Trajectory.new(:tool_call, %{action: :read, path: "lib/exy.ex"})
    ]

    text = Exy.Context.serialize(events)
    assert text =~ "[User]: Build Exy"
    assert text =~ "[Assistant]"
    assert text =~ "[Assistant tool call]"
  end

  test "subagents run under supervision and record trajectory" do
    specs = [
      %{role: :a, goal: "one", run: fn _ -> 1 end},
      %{role: :b, goal: "two", run: fn _ -> 2 end}
    ]

    assert {:ok, results} = Exy.Subagents.run_many(specs, max_concurrency: 2)
    assert Enum.map(results, & &1.status) == [:ok, :ok]
    assert Enum.map(results, & &1.result) == [1, 2]

    events = Exy.Trajectory.Store.list()
    assert Enum.count(events, &(&1.type == :subagent_started)) == 2
    assert Enum.count(events, &(&1.type == :subagent_finished)) == 2
  end
end
