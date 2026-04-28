defmodule Exy.AgentTest do
  use ExUnit.Case, async: false

  setup do
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

    Exy.Session.Store.clear()
    {:ok, session_dir: session_dir}
  end

  test "coding agent has a practically unbounded iteration ceiling" do
    assert Exy.Agent.Coding.strategy_opts()[:max_iterations] >= 1_000_000
  end

  test "sessions are optional and attached to the pid" do
    {:ok, pid} = Exy.start_link(session_id: "agent-session")

    assert {:error, _reason} = Exy.ask(pid, "hello", timeout: 1)
    assert [%{id: "agent-session"}] = Exy.Session.Store.list()
    assert [user, assistant | _] = Exy.Session.Store.events("agent-session")
    assert user.type == :user_message
    assert user.data.prompt == "hello"
    assert assistant.type == :assistant_message
  end
end
