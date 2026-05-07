defmodule Vibe.ToolOutputTest do
  use ExUnit.Case, async: true

  @large_item_count 10_000
  @structured_limit_bytes 1_000

  test "keeps text under the default context limit" do
    text = String.duplicate("x", Vibe.ToolOutput.default_max_bytes() + 10)

    output = Vibe.ToolOutput.limit_text(text)

    assert byte_size(output) > Vibe.ToolOutput.default_max_bytes()
    assert output =~ "tool output truncated"
    assert output =~ "10 bytes omitted"
  end

  test "small structured values remain encodable through project Jason encoders" do
    value = %{matches: [{"lib/a.ex", 1}], date: ~D[2026-04-27]}

    assert Vibe.ToolOutput.limit_value(value) == value
    assert Jason.encode!(value) == ~s({"date":"2026-04-27","matches":[["lib/a.ex",1]]})
  end

  test "large structured values become a bounded textual tool result" do
    value = %{items: Enum.map(1..@large_item_count, &%{n: &1, text: String.duplicate("x", 20)})}

    output = Vibe.ToolOutput.limit_value(value, @structured_limit_bytes)

    assert %{truncated: true, limit_bytes: @structured_limit_bytes, output: text} = output
    assert byte_size(text) > @structured_limit_bytes
    assert text =~ "tool output truncated"
  end

  test "limits content by bytes and lines with accurate omitted metadata" do
    result = Vibe.ToolOutput.limit_content("one\ntwo\nthree", limit_lines: 2, limit_bytes: 7)

    assert result.content == "one\ntwo"
    assert result.omitted_lines > 0
    assert result.omitted_bytes == 6
    assert result.truncated?
  end
end
