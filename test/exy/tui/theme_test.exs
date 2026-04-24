defmodule Exy.TUI.ThemeTest do
  use ExUnit.Case, async: true

  test "provides dark and light themes" do
    assert Exy.TUI.Theme.dark().name == "dark"
    assert Exy.TUI.Theme.light().name == "light"
    assert Exy.TUI.Theme.named("light").name == "light"
  end

  test "applies semantic foreground colors with ANSI reset" do
    styled = Exy.TUI.Theme.default() |> Exy.TUI.Theme.fg(:error, "boom")

    styled = IO.iodata_to_binary(styled)

    assert styled =~ IO.ANSI.red()
    assert styled =~ IO.ANSI.reset()
    assert Exy.TUI.Theme.strip(styled) == "boom"
  end

  test "applies RGB backgrounds through IO.ANSI color cube" do
    styled = Exy.TUI.Theme.default() |> Exy.TUI.Theme.bg(:tool_pending_bg, "tool")

    styled = IO.iodata_to_binary(styled)

    assert styled =~ IO.ANSI.color_background(1, 1, 1)
    assert Exy.TUI.Theme.strip(styled) == "tool"
  end
end
