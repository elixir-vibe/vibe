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
end
