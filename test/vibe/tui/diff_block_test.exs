defmodule Vibe.TUI.DiffBlockTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{DiffBlock, Theme, Width}

  test "colors added and removed diff lines" do
    rendered =
      ["+ 1  added", "- 2  removed", "  3  same"]
      |> DiffBlock.diff_lines("elixir", 80, Theme.default())
      |> IO.iodata_to_binary()

    assert rendered =~ "added"
    assert rendered =~ "removed"
    assert rendered =~ "\e[38;2;"
  end

  test "wraps diff output to available width" do
    lines = DiffBlock.diff_lines(["+ 1  " <> String.duplicate("x", 40)], nil, 14, Theme.default())

    assert length(lines) > 1
    assert Enum.all?(lines, &(Width.visible_length(&1) <= 14))
  end
end
