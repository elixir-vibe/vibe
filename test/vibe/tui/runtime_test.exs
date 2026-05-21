defmodule Vibe.TUI.RuntimeTest do
  use ExUnit.Case, async: false

  alias Ghostty.Terminal
  alias Vibe.TUI.TerminalLoop

  @cols 100
  @rows 30

  test "render frame uses synchronized full-frame repaint controls" do
    frame =
      Vibe.TUI.Runtime.render_frame(["top", "middle", "bottom"], {4, 3}, 2)
      |> IO.iodata_to_binary()

    assert frame =~ "\e[?2026h"
    assert frame =~ "\e[?2026l"
    assert frame =~ "\e[?7l"
    assert frame =~ "\e[?7h"
    assert frame =~ IO.ANSI.cursor(2, 1)
    assert frame =~ IO.ANSI.cursor(4, 1)
    assert frame =~ IO.ANSI.cursor(4, 3)
  end

  test "render frame can pin the prompt to the bottom rows" do
    assert {:ok, terminal} = Terminal.start_link(cols: @cols, rows: @rows)
    {lines, cursor} = rendered_textarea("")
    start_row = @rows - length(lines) + 1

    Terminal.write(terminal, Vibe.TUI.Runtime.render_frame(lines, cursor, start_row))

    {:ok, screen} = Terminal.snapshot(terminal, :plain)
    render_state = Terminal.render_state(terminal)
    screen_lines = String.split(screen, "\n")

    assert Enum.at(screen_lines, start_row - 1) |> String.starts_with?("~/")
    assert Enum.at(screen_lines, start_row) |> String.starts_with?("╭")
    assert last_item(screen_lines) |> String.starts_with?("╰")
    assert {render_state.cursor.y + 1, render_state.cursor.x + 1} == cursor
    refute Enum.any?(Enum.slice(screen_lines, 0, start_row - 1), &String.contains?(&1, "Prompt"))
  end

  test "render frame leaves terminal content and cursor stable after every typed character" do
    assert {:ok, terminal} = Terminal.start_link(cols: @cols, rows: @rows)
    text = "hello world this is a long prompt that wraps across textarea rows"

    Enum.reduce(String.graphemes(text), "", fn grapheme, typed ->
      typed = typed <> grapheme
      {lines, cursor} = rendered_textarea(typed)

      start_row = @rows - length(lines) + 1
      Terminal.write(terminal, Vibe.TUI.Runtime.render_frame(lines, cursor, start_row))

      {:ok, screen} = Terminal.snapshot(terminal, :plain)
      render_state = Terminal.render_state(terminal)

      assert_textarea_shape!(screen)
      assert String.contains?(screen, typed)
      assert render_state.cursor.visible
      assert {render_state.cursor.y + 1, render_state.cursor.x + 1} == cursor

      typed
    end)
  end

  test "runtime resize sync updates loop and invalidates painter" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 100, height: 30)
    painter = Vibe.TUI.TerminalPainter.new(100, 30)

    assert {^painter, false} = Vibe.TUI.Runtime.resize_painter(loop, painter, {100, 30})

    {resized, true} = Vibe.TUI.Runtime.resize_painter(loop, painter, {60, 20})
    assert resized.width == 60
    assert resized.height == 20
    assert resized.lines == []

    lines = TerminalLoop.render_full(loop)
    assert Enum.max(Enum.map(lines, &Vibe.TUI.Width.visible_length/1)) <= 60
  end

  test "runtime supervisor preserves caller-provided live session server" do
    {:ok, session} = Vibe.Session.start_link(persist?: false, session_id: "remote-runtime")
    runtime_id = make_ref()

    {:ok, supervisor} =
      Vibe.TUI.RuntimeSupervisor.start_link(
        runtime_id: runtime_id,
        session_id: "remote-runtime",
        session_server: session,
        width: @cols,
        height: @rows,
        output: false
      )

    app = Vibe.TUI.RuntimeSupervisor.name(runtime_id, :app)
    :ok = Vibe.TUI.App.subscribe(app, self())

    :ok =
      Vibe.Session.emit_event(
        session,
        Vibe.Event.new(:notification_added, "remote-runtime", %{text: "live event"})
      )

    assert_receive {Vibe.TUI.App, :event,
                    %{type: :notification_added, data: %{text: "live event"}}}

    assert [%{text: "live event"}] = Vibe.TUI.App.snapshot(app).ui.notifications

    Supervisor.stop(supervisor)
    GenServer.stop(session)
  end

  defp rendered_textarea(text) do
    {:ok, loop} =
      TerminalLoop.start_link(
        width: @cols,
        height: @rows,
        output: false,
        ask_fun: fn _prompt -> "" end
      )

    TerminalLoop.input(loop, text)
    {TerminalLoop.render(loop), TerminalLoop.cursor_position(loop)}
  end

  defp assert_textarea_shape!(screen) do
    assert textarea_shape?(screen)
  end

  defp textarea_shape?(screen) do
    lines = String.split(screen, "\n")

    top = Enum.find(lines, &String.starts_with?(&1, "╭"))
    bottom = Enum.find(lines, &String.starts_with?(&1, "╰"))
    body = Enum.filter(lines, &(String.starts_with?(&1, "│") and String.ends_with?(&1, "│")))

    top && String.ends_with?(top, "╮") && bottom && String.ends_with?(bottom, "╯") &&
      length(body) >= 3
  end

  defp last_item([item]), do: item
  defp last_item([_item | items]), do: last_item(items)
end
