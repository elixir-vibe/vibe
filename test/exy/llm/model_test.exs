defmodule Exy.LLM.ModelTest do
  use ExUnit.Case, async: true

  test "default model is newest ChatGPT Codex model" do
    assert Exy.LLM.Model.default() == "openai_codex:gpt-5.5"
    assert Exy.LLM.Model.resolve() == "openai_codex:gpt-5.5"

    assert Exy.LLM.Model.resolve(model: "anthropic:claude-sonnet-4-5-20250929") ==
             "anthropic:claude-sonnet-4-5-20250929"
  end
end
