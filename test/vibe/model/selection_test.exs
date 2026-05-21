defmodule Vibe.Model.SelectionTest do
  use ExUnit.Case, async: false

  test "default model is newest ChatGPT Codex model" do
    assert Vibe.Model.Selection.default() == "openai_codex:gpt-5.5"
    assert Vibe.Model.Selection.resolve() == "openai_codex:gpt-5.5"

    assert Vibe.Model.Selection.resolve(model: "anthropic:claude-sonnet-4-5-20250929") ==
             "anthropic:claude-sonnet-4-5-20250929"
  end

  test "available_providers returns a list of atoms" do
    providers = Vibe.Model.Selection.available_providers()
    assert is_list(providers)
    assert Enum.all?(providers, &is_atom/1)
    assert providers == Enum.sort(providers)
  end
end
