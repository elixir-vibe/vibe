defmodule Exy.TUI.TerminalPainterTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.TerminalPainter

  test "patches large histories without quadratic scans" do
    lines = Enum.map(1..10_000, &["line ", Integer.to_string(&1)])
    {_, painter} = TerminalPainter.render(TerminalPainter.new(120, 30), lines, {10_000, 1})
    changed = List.replace_at(lines, 9_999, "changed")

    {us, {_frame, _painter}} =
      :timer.tc(fn -> TerminalPainter.render(painter, changed, {10_000, 1}) end)

    assert us < 50_000
  end

  test "first render paints a synchronized full frame" do
    painter = TerminalPainter.new(20, 5)
    {frame, painter} = TerminalPainter.render(painter, ["hello"], {1, 6})
    frame = IO.iodata_to_binary(frame)

    assert frame =~ "\e[?2026h"
    assert frame =~ "\e[2J"
    refute frame =~ "\e[3J"
    assert frame =~ "hello"
    assert painter.lines == ["", "", "", "", "hello"]
    assert painter.viewport_top == 1
  end

  test "clears stale rows when a document shrinks" do
    {:ok, terminal} = Ghostty.Terminal.start_link(cols: 40, rows: 5)
    painter = TerminalPainter.new(40, 5)
    {frame, painter} = TerminalPainter.render(painter, ["one", "two", "three", "four"], {4, 1})
    :ok = Ghostty.Terminal.write(terminal, frame)

    {frame, _painter} = TerminalPainter.render(painter, ["one", "two"], {2, 1})
    :ok = Ghostty.Terminal.write(terminal, frame)

    assert {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
    refute screen =~ "three"
    refute screen =~ "four"
  end

  test "single-line updates patch without clearing scrollback" do
    painter = TerminalPainter.new(20, 5)
    {_frame, painter} = TerminalPainter.render(painter, ["one", "two"], {2, 4})
    {frame, painter} = TerminalPainter.render(painter, ["one", "TWO"], {2, 4})
    frame = IO.iodata_to_binary(frame)

    assert frame =~ "TWO"
    assert frame =~ "\e[2K"
    refute frame =~ "\e[2J"
    refute frame =~ "\e[3J"
    assert painter.lines == ["", "", "", "one", "TWO"]
  end

  test "appended content scrolls native terminal history with newlines" do
    painter = TerminalPainter.new(20, 3)
    {_frame, painter} = TerminalPainter.render(painter, ["one", "two", "three"], {3, 6})
    {frame, painter} = TerminalPainter.render(painter, ["one", "two", "three", "four"], {4, 5})
    frame = IO.iodata_to_binary(frame)

    assert frame =~ "\r\n"
    assert frame =~ "four"
    assert painter.viewport_top == 2
  end

  test "width resize invalidates lines and clears scrollback on next render" do
    painter = TerminalPainter.new(20, 5)
    {_frame, painter} = TerminalPainter.render(painter, ["hello"], {1, 6})
    painter = TerminalPainter.resize(painter, 30, 5)

    assert painter.lines == []
    assert painter.clear_scrollback?

    {frame, painter} = TerminalPainter.render(painter, ["hello reflowed"], {1, 15})
    frame = IO.iodata_to_binary(frame)

    assert frame =~ "\e[3J"
    assert frame =~ "hello reflowed"
    refute painter.clear_scrollback?
  end

  test "height-only resize keeps previous lines and avoids scrollback clear" do
    painter = TerminalPainter.new(20, 5)
    {_frame, painter} = TerminalPainter.render(painter, ["hello"], {1, 6})
    painter = TerminalPainter.resize(painter, 20, 8)

    assert painter.lines != []
    refute painter.clear_scrollback?
  end
end
