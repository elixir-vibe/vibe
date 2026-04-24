defmodule Exy.LLM.UsageTest do
  use ExUnit.Case, async: true

  test "extracts and summarizes model response usage" do
    usage =
      Exy.LLM.Usage.from_response(%{
        model: "openai_codex:gpt-5.5",
        usage: %{input_tokens: 4, output_tokens: 6, total_tokens: 10, total_cost: 0.2}
      })

    assert usage.model == "openai_codex:gpt-5.5"
    assert usage.input_tokens == 4
    assert Exy.LLM.Usage.summarize([usage]).total_tokens == 10
  end
end
