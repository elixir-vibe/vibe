defmodule Exy.CLI.SessionsTest do
  use ExUnit.Case, async: false

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "exy-cli-sessions-test-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :session_dir, previous),
        else: Application.delete_env(:exy, :session_dir)

      File.rm_rf(session_dir)
    end)

    Exy.Session.Store.clear()
    :ok
  end

  test "latest_live_remote_session_id returns nil without remote server" do
    assert is_nil(Exy.CLI.Sessions.latest_live_remote_session_id())
  end
end
