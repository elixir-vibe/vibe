defmodule Vibe.TUI.TerminalPainterTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.TerminalPainter

  @large_history_lines 10_000
  @last_large_history_index 9_999
  @patch_budget_us 50_000

  test "patches large histories without quadratic scans" do
    lines = Enum.map(1..@large_history_lines, &["line ", Integer.to_string(&1)])

    {_, painter} =
      TerminalPainter.render(TerminalPainter.new(120, 30), lines, {@large_history_lines, 1})

    changed = List.replace_at(lines, @last_large_history_index, "changed")

    {us, {_frame, _painter}} =
      :timer.tc(fn -> TerminalPainter.render(painter, changed, {@large_history_lines, 1}) end)

    assert us < @patch_budget_us
  end

  test "first render appends without clearing existing terminal history" do
    {:ok, terminal} = Ghostty.Terminal.start_link(cols: 20, rows: 5, max_scrollback: 100)
    :ok = Ghostty.Terminal.write(terminal, "before 1\r\nbefore 2\r\nbefore 3\r\n")

    painter = TerminalPainter.new(20, 5)
    {frame, painter} = TerminalPainter.render(painter, ["hello"], {1, 6})
    frame = IO.iodata_to_binary(frame)

    assert frame =~ "\e[?2026h"
    refute frame =~ "\e[2J"
    refute frame =~ "\e[3J"
    assert frame =~ "hello"

    :ok = Ghostty.Terminal.write(terminal, frame)
    :ok = Ghostty.Terminal.scroll(terminal, -100)
    assert {:ok, scrollback} = Ghostty.Terminal.snapshot(terminal, :plain)
    assert scrollback =~ "before 1"
    assert scrollback =~ "before 2"
    assert scrollback =~ "before 3"
    assert scrollback =~ "hello"
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

  test "appended content scrolls native terminal history like Pi" do
    painter = TerminalPainter.new(20, 3)
    {_frame, painter} = TerminalPainter.render(painter, ["one", "two", "three"], {3, 6})
    {frame, painter} = TerminalPainter.render(painter, ["one", "two", "three", "four"], {4, 5})
    frame = IO.iodata_to_binary(frame)

    assert frame =~ "\r\n"
    refute frame =~ IO.ANSI.clear()
    assert frame =~ "four"
    assert painter.viewport_top == 2
  end

  test "width resize invalidates lines without clearing terminal scrollback" do
    painter = TerminalPainter.new(20, 5)
    {_frame, painter} = TerminalPainter.render(painter, ["hello"], {1, 6})
    painter = TerminalPainter.resize(painter, 30, 5)

    assert painter.lines == []

    {frame, _painter} = TerminalPainter.render(painter, ["hello reflowed"], {1, 15})
    frame = IO.iodata_to_binary(frame)

    refute frame =~ "\e[3J"
    assert frame =~ "hello reflowed"
  end

  test "height-only resize keeps previous lines" do
    painter = TerminalPainter.new(20, 5)
    {_frame, painter} = TerminalPainter.render(painter, ["hello"], {1, 6})
    painter = TerminalPainter.resize(painter, 20, 8)

    assert painter.lines != []
  end
end
