defmodule Exy.Agent.UsageTest do
  use ExUnit.Case, async: true

  test "extracts and summarizes model response usage" do
    usage =
      Exy.Agent.Usage.from_response(%{
        model: "openai_codex:gpt-5.5",
        usage: %{input_tokens: 4, output_tokens: 6, total_tokens: 10, total_cost: 0.2}
      })

    assert usage.model == "openai_codex:gpt-5.5"
    assert usage.input_tokens == 4
    assert Exy.Agent.Usage.summarize([usage]).total_tokens == 10
  end

  test "extracts usage from agent output wrappers" do
    usage =
      Exy.Agent.Usage.from_response(%{
        output: "Hi!",
        usage: %{input_tokens: 12, output_tokens: 3, total_tokens: 15}
      })

    assert usage.input_tokens == 12
    assert usage.output_tokens == 3
    assert usage.total_tokens == 15
  end

  test "summarizes total tokens from input and output when provider omits total" do
    assert %{total_tokens: 10} =
             Exy.Agent.Usage.summarize([%{input_tokens: 4, output_tokens: 6}])
  end
end
