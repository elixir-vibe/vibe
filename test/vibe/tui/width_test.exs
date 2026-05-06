defmodule Vibe.TUI.WidthTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.Width

  test "counts terminal cells, not graphemes" do
    assert Width.visible_length("a") == 1
    assert Width.visible_length("🚀") == 2
    assert Width.visible_length("⚗️") == 2
    assert Width.visible_length("東") == 2
    assert Width.visible_length("é") == 1
    assert Width.visible_length("🏳️‍🌈") == 2
  end

  test "takes text by terminal cells" do
    assert Width.take("ab🚀cd", 4) == "ab🚀"
    assert Width.take("ab🚀cd", 3) == "ab"
  end

  test "chunks text by terminal cells" do
    assert Width.chunks("a🚀b東c", 3) == ["a🚀", "b東", "c"]
  end
end
