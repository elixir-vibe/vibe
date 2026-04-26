defmodule Exy.Agent.ModelTest do
  use ExUnit.Case, async: false

  test "default model is newest ChatGPT Codex model" do
    assert Exy.Agent.Model.default() == "openai_codex:gpt-5.5"
    assert Exy.Agent.Model.resolve() == "openai_codex:gpt-5.5"

    assert Exy.Agent.Model.resolve(model: "anthropic:claude-sonnet-4-5-20250929") ==
             "anthropic:claude-sonnet-4-5-20250929"
  end
end
