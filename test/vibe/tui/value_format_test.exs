defmodule Vibe.TUI.ValueFormatTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{Theme, ValueFormat, Width}

  test "summarizes values as single lines" do
    assert ValueFormat.summarize("hello\nworld", :infinity) == "hello world"
    assert ValueFormat.summarize(%{answer: 42}, 80) =~ "answer"
  end

  test "formats plain lines with wrapping and padding" do
    lines = ValueFormat.plain_lines("hello world", 8, Theme.default())

    assert [_ | _] = lines
    assert Enum.all?(lines, &(Width.visible_length(&1) <= 8))
    assert lines |> hd() |> Width.visible_text() |> String.starts_with?("  ")
  end

  test "formats inspect lines with syntax highlighting" do
    rendered =
      ValueFormat.inspect_lines("%{ok: true}", 80, Theme.default()) |> IO.iodata_to_binary()

    assert rendered =~ "\e[38;2;"
    assert rendered =~ "ok"
  end

  test "formats error terms" do
    assert ValueFormat.format_error(%{error: :boom}) =~ "boom"

    rendered = ValueFormat.error_lines("boom", 80, Theme.default()) |> IO.iodata_to_binary()
    assert rendered =~ "boom"
  end
end
