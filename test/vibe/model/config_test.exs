defmodule Vibe.Model.ConfigTest do
  use ExUnit.Case, async: false

  test "default model is newest ChatGPT Codex model" do
    assert Vibe.Model.Config.default() == "openai_codex:gpt-5.5"
    assert Vibe.Model.Config.resolve() == "openai_codex:gpt-5.5"

    assert Vibe.Model.Config.resolve(model: "anthropic:claude-sonnet-4-5-20250929") ==
             "anthropic:claude-sonnet-4-5-20250929"
  end

  test "available_providers returns a list of atoms" do
    providers = Vibe.Model.Config.available_providers()
    assert is_list(providers)
    assert Enum.all?(providers, &is_atom/1)
    assert providers == Enum.sort(providers)
  end
end
