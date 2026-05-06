defmodule Vibe.Auth.OpenRouterTest do
  use ExUnit.Case, async: false

  setup do
    home =
      Path.join(System.tmp_dir!(), "vibe-openrouter-auth-#{System.unique_integer([:positive])}")

    old_home = System.get_env("VIBE_HOME")
    old_key = System.get_env("OPENROUTER_API_KEY")
    System.put_env("VIBE_HOME", home)
    System.delete_env("OPENROUTER_API_KEY")

    on_exit(fn ->
      restore_env("VIBE_HOME", old_home)
      restore_env("OPENROUTER_API_KEY", old_key)
      File.rm_rf(home)
    end)

    {:ok, home: home}
  end

  test "registers as auth provider" do
    assert Vibe.Auth.provider("openrouter") == Vibe.Auth.OpenRouter
  end

  test "loads key from environment and installs ReqLLM key" do
    System.put_env("OPENROUTER_API_KEY", "sk-or-test")

    assert {:ok, %{"api_key" => "sk-or-test"}} = Vibe.Auth.OpenRouter.ensure_fresh()
    assert Application.get_env(:vibe, :openrouter_credentials) == %{api_key: "sk-or-test"}
  end

  test "login stores api key" do
    assert {:ok, %{"api_key" => "sk-or-stored"}} =
             Vibe.Auth.OpenRouter.login(api_key: "sk-or-stored")

    assert {:ok, %{"api_key" => "sk-or-stored"}} = Vibe.Auth.Store.load("openrouter")
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
