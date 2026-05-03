defmodule Exy.Auth.OpenCodeTest do
  use ExUnit.Case, async: false

  alias Exy.Auth.OpenCode

  setup do
    previous = Application.get_env(:exy, :opencode_credentials)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :opencode_credentials, previous),
        else: Application.delete_env(:exy, :opencode_credentials)
    end)

    :ok
  end

  test "put_credentials stores api key in application env" do
    assert :ok = OpenCode.put_credentials(%{"api_key" => "sk-test-123"})
    assert OpenCode.api_key() == "sk-test-123"
  end

  test "put_credentials accepts atom keys" do
    assert :ok = OpenCode.put_credentials(%{api_key: "sk-test-456"})
    assert OpenCode.api_key() == "sk-test-456"
  end

  test "api_key returns nil when not configured" do
    Application.delete_env(:exy, :opencode_credentials)
    assert OpenCode.api_key() == nil
  end

  test "load falls back to OPENCODE_API_KEY env var" do
    previous_home = Application.get_env(:exy, :home_dir)
    tmp = Path.join(System.tmp_dir!(), "exy-opencode-test-#{System.unique_integer([:positive])}")
    Application.put_env(:exy, :home_dir, tmp)
    System.put_env("OPENCODE_API_KEY", "sk-env-test")

    try do
      assert {:ok, %{"api_key" => "sk-env-test"}} = OpenCode.load()
    after
      System.delete_env("OPENCODE_API_KEY")

      if previous_home,
        do: Application.put_env(:exy, :home_dir, previous_home),
        else: Application.delete_env(:exy, :home_dir)

      File.rm_rf(tmp)
    end
  end
end
