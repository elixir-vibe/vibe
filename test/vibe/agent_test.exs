defmodule Vibe.AgentTest do
  use ExUnit.Case, async: false

  @practical_iteration_floor 1_000_000

  setup do
    session_dir =
      Path.join(
        System.tmp_dir!(),
        "vibe-agent-session-test-#{System.unique_integer([:positive])}"
      )

    previous = Application.get_env(:vibe, :session_dir)
    Application.put_env(:vibe, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :session_dir, previous),
        else: Application.delete_env(:vibe, :session_dir)

      File.rm_rf(session_dir)
    end)

    Vibe.Session.Store.clear()
    {:ok, session_dir: session_dir}
  end

  test "coding agent has a practically unbounded iteration ceiling" do
    assert Vibe.Agent.Coding.strategy_opts()[:max_iterations] >= @practical_iteration_floor
  end

  test "sessions are optional and attached to the pid" do
    {:ok, pid} = Vibe.start_link(session_id: "agent-session")

    assert {:error, _reason} = Vibe.ask(pid, "hello", timeout: 1)
    assert [%{id: "agent-session"}] = Vibe.Session.Store.list()
    assert [user, assistant | _] = Vibe.Session.Store.events("agent-session")
    assert user.type == :user_message
    assert user.data.prompt == "hello"
    assert assistant.type == :assistant_message
  end
end
