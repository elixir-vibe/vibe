defmodule Vibe.Tool.OutputTest do
  use ExUnit.Case, async: true

  alias Vibe.Tool.Output.Window

  @large_item_count 10_000
  @structured_limit_bytes 1_000

  test "builds reusable tail windows with full output pointers" do
    text = Enum.map_join(1..5, "\n", &"line #{&1}")

    window = Window.build(text, mode: :tail, limit_lines: 2, full_output_path: "/tmp/full.log")

    assert window.truncated?
    assert window.text == "line 4\nline 5"
    assert Window.notice(window) == "[Showing lines 4-5 of 5. Full output: /tmp/full.log]"
  end

  test "limits text output with reusable window notices" do
    text = Enum.map_join(1..5, "\n", &"line #{&1}")

    assert Vibe.Tool.Output.limit_text(text,
             mode: :tail,
             limit_lines: 2,
             full_output_path: "/tmp/full.log"
           ) == "line 4\nline 5\n\n[Showing lines 4-5 of 5. Full output: /tmp/full.log]"
  end

  test "keeps text under the default context limit" do
    text = String.duplicate("x", Vibe.Tool.Output.default_max_bytes() + 10)

    output = Vibe.Tool.Output.limit_text(text)

    assert byte_size(output) > Vibe.Tool.Output.default_max_bytes()
    assert output =~ "tool output truncated"
    assert output =~ "10 bytes omitted"
  end

  test "small structured values remain encodable through explicit JSON projection" do
    value = %{matches: [{"lib/a.ex", 1}], date: ~D[2026-04-27]}

    assert Vibe.Tool.Output.limit_value(value) == value

    assert Jason.encode!(Vibe.JSON.Encode.value(value)) ==
             ~s({"date":"2026-04-27","matches":[["lib/a.ex",1]]})
  end

  test "large structured values become a bounded textual tool result" do
    value = %{items: Enum.map(1..@large_item_count, &%{n: &1, text: String.duplicate("x", 20)})}

    output = Vibe.Tool.Output.limit_value(value, @structured_limit_bytes)

    assert %{truncated: true, limit_bytes: @structured_limit_bytes, output: text} = output
    assert byte_size(text) > @structured_limit_bytes
    assert text =~ "tool output truncated"
  end

  test "limits content by bytes and lines with accurate omitted metadata" do
    result = Vibe.Tool.Output.limit_content("one\ntwo\nthree", limit_lines: 2, limit_bytes: 7)

    assert result.content == "one\ntwo"
    assert result.omitted_lines > 0
    assert result.omitted_bytes == 6
    assert result.truncated?
  end
end
