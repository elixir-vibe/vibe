defmodule Exy.LLMTest do
  use ExUnit.Case, async: false

  setup do
    previous_credentials = Application.get_env(:exy, :openai_codex_credentials)
    previous_oauth_file = Application.get_env(:req_llm, :oauth_file)

    on_exit(fn ->
      restore_env(:exy, :openai_codex_credentials, previous_credentials)
      restore_env(:req_llm, :oauth_file, previous_oauth_file)
    end)

    :ok
  end

  test "stores codex credentials for OAuth requests" do
    assert :ok = Exy.LLM.put_codex_credentials(%{access: "token", accountId: "account"})

    assert %{access: "token", accountId: "account"} =
             Application.get_env(:exy, :openai_codex_credentials)

    assert Application.get_env(:req_llm, :oauth_file) == Path.expand("~/.exy/auth.json")
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
