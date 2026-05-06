defmodule Vibe.TUI.SourceBlockTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{SourceBlock, Theme, Width}

  test "renders plain source lines without language" do
    lines = SourceBlock.source_lines(["hello", "world"], nil, 20, Theme.default())

    assert Enum.map(lines, &Width.visible_text/1) == ["  hello", "  world"]
  end

  test "highlights source as a block for multiline Elixir" do
    lines =
      SourceBlock.source_lines(
        ["defmodule Demo do", "  @moduledoc \"\"\"", "  hello", "  \"\"\"", "end"],
        "elixir",
        80,
        Theme.default()
      )

    rendered = IO.iodata_to_binary(lines)

    assert rendered =~ "\e[38;2;"
    assert Enum.any?(lines, &(Width.visible_text(&1) =~ ~s(@moduledoc)))
  end
end
