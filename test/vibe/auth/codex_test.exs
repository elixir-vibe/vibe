defmodule Vibe.Auth.CodexTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    previous_home = System.get_env("VIBE_HOME")

    home =
      Path.join(System.tmp_dir!(), "vibe-codex-auth-test-#{System.unique_integer([:positive])}")

    System.put_env("VIBE_HOME", home)
    File.rm_rf!(home)

    on_exit(fn ->
      if previous_home,
        do: System.put_env("VIBE_HOME", previous_home),
        else: System.delete_env("VIBE_HOME")

      File.rm_rf!(home)
    end)

    :ok
  end

  test "auth store persists atom-keyed oauth credentials as JSON-safe data" do
    credentials = %{
      type: "oauth",
      access: "access-token",
      refresh: "refresh-token",
      expires: 1_777_389_000_000,
      accountId: "account-id"
    }

    assert :ok = Vibe.Auth.Store.save("openai-codex", credentials)
    assert {:ok, loaded} = Vibe.Auth.Store.load("openai-codex")

    assert loaded["type"] == "oauth"
    assert loaded["access"] == "access-token"
    assert loaded["refresh"] == "refresh-token"
    assert loaded["accountId"] == "account-id"
  end

  test "login prints failure reason" do
    output =
      capture_io(:stderr, fn ->
        assert {:error, _reason} = Vibe.Auth.Codex.login(open_browser: false, timeout: 1)
      end)

    assert output =~ "ChatGPT/Codex sign-in failed"
  end
end
