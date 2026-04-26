defmodule Exy.Model.ConfigTest do
  use ExUnit.Case, async: false

  test "default model is newest ChatGPT Codex model" do
    assert Exy.Model.Config.default() == "openai_codex:gpt-5.5"
    assert Exy.Model.Config.resolve() == "openai_codex:gpt-5.5"

    assert Exy.Model.Config.resolve(model: "anthropic:claude-sonnet-4-5-20250929") ==
             "anthropic:claude-sonnet-4-5-20250929"
  end
end
