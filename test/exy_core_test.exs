defmodule ExyCoreTest do
  use ExUnit.Case, async: false

  setup do
    Exy.Trajectory.Store.clear()
    :ok
  end

  test "default model is newest ChatGPT Codex model" do
    assert Exy.Model.default() == "openai_codex:gpt-5.5"
    assert Exy.Model.resolve() == "openai_codex:gpt-5.5"

    assert Exy.Model.resolve(model: "anthropic:claude-sonnet-4-5-20250929") ==
             "anthropic:claude-sonnet-4-5-20250929"
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

  test "checks analysis gives agent-friendly summary without reruns" do
    report = Exy.Checks.analyze(checks: [:reach])

    assert report.ok?
    assert report.failed == []
    assert [%{name: :reach, status: :ok}] = report.summary
    assert [%{name: :reach, status: :ok, details: %{files: files}}] = report.results
    assert files > 0
  end

  test "action schemas use JSONSpec directly" do
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{"code" => "1 + 1"})
    assert %{code: "1 + 1"} = JSONSpec.atomize(Exy.Actions.Eval.schema(), %{code: "1 + 1"})
  end

  test "session JSONL persists trajectory events" do
    session_dir =
      Path.join(System.tmp_dir!(), "exy-session-test-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :session_dir, previous),
        else: Application.delete_env(:exy, :session_dir)

      File.rm_rf(session_dir)
    end)

    session_id = "test-session"
    Exy.Trajectory.Store.append(:user_message, %{prompt: "hello"}, session_id: session_id)

    Exy.Trajectory.Store.append(:llm_usage, %{input_tokens: 2, output_tokens: 3, total_tokens: 5},
      session_id: session_id
    )

    assert File.exists?(Exy.Session.path(session_id))
    assert [%{id: ^session_id, path: path}] = Exy.Session.list()
    assert path == Exy.Session.path(session_id)

    assert [user, usage] = Exy.Session.events(session_id)
    assert user.type == :user_message
    assert user.data.prompt == "hello"
    assert usage.type == :llm_usage
    assert usage.data.total_tokens == 5
  end

  test "usage extraction normalizes model response usage" do
    usage =
      Exy.Usage.from_response(%{
        model: "openai_codex:gpt-5.5",
        usage: %{input_tokens: 4, output_tokens: 6, total_tokens: 10, total_cost: 0.2}
      })

    assert usage.model == "openai_codex:gpt-5.5"
    assert usage.input_tokens == 4
    assert Exy.Usage.summarize([usage]).total_tokens == 10
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

  test "script runner supports Mix.install style scripts in another BEAM" do
    result =
      Exy.Script.run_string(~s'''
      Mix.install([])
      IO.puts("script ok")
      ''')

    assert result.status == :ok
    assert result.output =~ "script ok"
  end

  test "standalone runtime preserves Livebook-style evaluator context" do
    assert {:ok, runtime} = Exy.Runtime.start_link()
    assert {:ok, %{status: :ok, value: 3}} = Exy.Runtime.evaluate(runtime, "x = 1 + 2")
    assert {:ok, %{status: :ok, value: 6}} = Exy.Runtime.evaluate(runtime, "x * 2")
    assert :ok = Exy.Runtime.stop(runtime)
  end

  test "standalone runtime captures IO away from protocol output" do
    assert {:ok, runtime} = Exy.Runtime.start_link()

    assert {:ok, %{status: :ok, output: output, value: :ok}} =
             Exy.Runtime.evaluate(runtime, ~s|IO.puts("hello")|)

    assert output =~ "hello"
    assert :ok = Exy.Runtime.stop(runtime)
  end

  test "agent sessions are optional and attached to the pid" do
    session_dir =
      Path.join(System.tmp_dir!(), "exy-agent-session-test-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :session_dir, previous),
        else: Application.delete_env(:exy, :session_dir)

      File.rm_rf(session_dir)
    end)

    {:ok, pid} = Exy.start_link(session_id: "agent-session")

    assert {:error, _reason} = Exy.ask(pid, "hello", timeout: 1)
    assert [%{id: "agent-session"}] = Exy.Session.list()
    assert [user, assistant | _] = Exy.Session.events("agent-session")
    assert user.type == :user_message
    assert user.data.prompt == "hello"
    assert assistant.type == :assistant_message
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
