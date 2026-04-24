defmodule Exy.TUI.ThemeTest do
  use ExUnit.Case, async: true

  test "applies semantic foreground colors with ANSI reset" do
    styled = Exy.TUI.Theme.default() |> Exy.TUI.Theme.fg(:error, "boom")

    assert styled =~ IO.ANSI.red()
    assert styled =~ IO.ANSI.reset()
    assert Exy.TUI.Theme.strip(styled) == "boom"
  end

  test "applies RGB backgrounds" do
    styled = Exy.TUI.Theme.default() |> Exy.TUI.Theme.bg(:tool_pending_bg, "tool")

    assert styled =~ "\e[48;2;38;38;38m"
    assert Exy.TUI.Theme.strip(styled) == "tool"
  end
end
