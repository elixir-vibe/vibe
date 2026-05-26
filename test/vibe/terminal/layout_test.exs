defmodule Vibe.Terminal.LayoutTest do
  use ExUnit.Case, async: true

  alias Vibe.Terminal.Layout

  test "fits lines by terminal cells" do
    assert Layout.fit_line("ab🚀cd", 4) == "ab🚀"
    assert Layout.fit_line("ab🚀cd", 3) == "ab"
    assert Layout.fit_line("ab🚀cd", 4, ellipsis?: true) == "ab…"
  end

  test "preserves ANSI styles while fitting" do
    assert Layout.fit_line("\e[31mhello\e[0m", 2) == "\e[31mhe\e[0m"
  end

  test "keeps short lines unpadded" do
    assert Layout.fit_line("hi", 4) == "hi"
  end

  test "wraps text by terminal cells" do
    assert Layout.wrap("hello world", 5) == ["hello", "world"]
    assert Layout.wrap("a🚀b東c", 3) == ["a🚀", "b東", "c"]
    assert Layout.wrap("one\ntwo", 10) == ["one", "two"]
  end

  test "sanitizes terminal controls before wrapping" do
    assert Layout.wrap("a\e[2Jb", 10) == ["ab"]
  end
end
