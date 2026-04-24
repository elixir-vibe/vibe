defmodule Exy.SessionTest do
  use ExUnit.Case, async: false

  setup do
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

    Exy.Trajectory.Store.clear()
    {:ok, session_dir: session_dir}
  end

  test "JSONL persists trajectory events" do
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
end
