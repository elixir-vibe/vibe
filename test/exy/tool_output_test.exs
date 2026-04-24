defmodule Exy.ToolOutputTest do
  use ExUnit.Case, async: true

  test "keeps text under the default context limit" do
    text = String.duplicate("x", Exy.ToolOutput.default_max_bytes() + 10)

    output = Exy.ToolOutput.limit_text(text)

    assert byte_size(output) > Exy.ToolOutput.default_max_bytes()
    assert output =~ "tool output truncated"
    assert output =~ "10 bytes omitted"
  end

  test "large structured values become a bounded textual tool result" do
    value = %{items: Enum.map(1..10_000, &%{n: &1, text: String.duplicate("x", 20)})}

    output = Exy.ToolOutput.limit_value(value, 1_000)

    assert %{truncated: true, limit_bytes: 1_000, output: text} = output
    assert byte_size(text) > 1_000
    assert text =~ "tool output truncated"
  end
end
