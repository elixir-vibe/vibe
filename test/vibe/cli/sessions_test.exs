defmodule Vibe.CLI.SessionsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "vibe-cli-sessions-test-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:vibe, :session_dir)
    Application.put_env(:vibe, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :session_dir, previous),
        else: Application.delete_env(:vibe, :session_dir)

      File.rm_rf(session_dir)
    end)

    Vibe.Session.Store.clear()
    :ok
  end

  test "latest_live_remote_session_id returns nil without remote server" do
    capture_io(:stderr, fn ->
      assert is_nil(Vibe.CLI.Sessions.latest_live_remote_session_id())
    end)
  end

  test "latest_live_session_id handles raw remote session listings for explicit attach" do
    sessions = [
      %{id: "old", live?: false},
      %{id: "current", live?: true},
      %{id: "other", live?: true}
    ]

    assert Vibe.CLI.Sessions.latest_live_session_id(sessions) == "current"
  end
end
