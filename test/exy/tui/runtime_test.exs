defmodule Exy.TUI.RuntimeTest do
  use ExUnit.Case, async: false

  alias Exy.TUI.TerminalLoop
  alias Ghostty.Terminal

  @cols 100
  @rows 30
  @startup_timeout_ms 20_000
  @input_timeout_ms 1_000
  @exit_timeout_ms 5_000
  @reader_start_timeout_ms 5_000

  test "render frame uses synchronized full-frame repaint controls" do
    frame =
      Exy.TUI.Runtime.render_frame(["top", "middle", "bottom"], {4, 3}, 2)
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

    Terminal.write(terminal, Exy.TUI.Runtime.render_frame(lines, cursor, start_row))

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
      Terminal.write(terminal, Exy.TUI.Runtime.render_frame(lines, cursor, start_row))

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
    painter = Exy.TUI.TerminalPainter.new(100, 30)

    assert {^painter, false} = Exy.TUI.Runtime.resize_painter(loop, painter, {100, 30})

    {resized, true} = Exy.TUI.Runtime.resize_painter(loop, painter, {60, 20})
    assert resized.width == 60
    assert resized.height == 20
    assert resized.lines == []
    assert resized.clear_scrollback?

    lines = TerminalLoop.render_full(loop)
    assert Enum.max(Enum.map(lines, &Exy.TUI.Width.visible_length/1)) <= 60
  end

  test "runtime supervisor preserves caller-provided live session server" do
    {:ok, session} = Exy.Session.start_link(persist?: false, session_id: "remote-runtime")
    runtime_id = make_ref()

    {:ok, supervisor} =
      Exy.TUI.RuntimeSupervisor.start_link(
        runtime_id: runtime_id,
        session_id: "remote-runtime",
        session_server: session,
        width: @cols,
        height: @rows,
        output: false
      )

    app = Exy.TUI.RuntimeSupervisor.name(runtime_id, :app)
    :ok = Exy.TUI.App.subscribe(app, self())

    :ok =
      Exy.Session.emit_event(
        session,
        Exy.UI.Event.new(:notification_added, "remote-runtime", %{text: "live event"})
      )

    assert_receive {Exy.TUI.App, :event,
                    %{type: :notification_added, data: %{text: "live event"}}}

    assert [%{text: "live event"}] = Exy.TUI.App.snapshot(app).ui.notifications

    Supervisor.stop(supervisor)
    GenServer.stop(session)
  end

  test "mix exy accepts input in a real PTY, escape cancels, and double ctrl-c exits" do
    {:ok, terminal} = Terminal.start_link(cols: @cols, rows: @rows)

    exy_home =
      Path.join(System.tmp_dir!(), "exy-runtime-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(exy_home)

    {:ok, pty} =
      Ghostty.PTY.start_link(
        cmd: "/bin/sh",
        args: ["-lc", "cd #{File.cwd!()} && EXY_HOME=#{shell_quote(exy_home)} mix exy"],
        cols: @cols,
        rows: @rows,
        reader_start_timeout: @reader_start_timeout_ms
      )

    try do
      assert {:ok, _output} = wait_for_screen_text(pty, terminal, "Exy", "", @startup_timeout_ms)

      assert {:ok, output} = wait_for_screen_text(pty, terminal, "╯", "", @input_timeout_ms)

      Ghostty.PTY.resize(pty, 60, 20)
      Terminal.resize(terminal, 60, 20)

      assert {:ok, output} =
               wait_for_screen(
                 pty,
                 terminal,
                 &textarea_shape?/1,
                 output,
                 @input_timeout_ms
               )

      type_and_assert_stable_frames(pty, terminal, "abc wraps across the prompt", output)

      {:ok, screen} = Terminal.snapshot(terminal, :plain)
      render_state = Terminal.render_state(terminal)

      refute String.contains?(screen, "BREAK:")
      assert_textarea_shape!(screen)
      assert render_state.cursor.visible

      Ghostty.PTY.write(pty, <<27>>)
      assert {:error, {:exit_timeout, _output}} = wait_for_exit("", 300)

      Ghostty.PTY.write(pty, <<3>>)
      Process.sleep(50)
      Ghostty.PTY.write(pty, <<3>>)
      assert {:exit, 0, _output} = wait_for_exit("", @exit_timeout_ms)
    after
      if Process.alive?(pty), do: Ghostty.PTY.close(pty)
      File.rm_rf(exy_home)
    end
  end

  defp shell_quote(value), do: "'" <> String.replace(value, "'", "'\\''") <> "'"

  defp type_and_assert_stable_frames(pty, terminal, text, output) do
    text
    |> String.graphemes()
    |> Enum.reduce({"", output}, fn grapheme, {typed, output} ->
      typed = typed <> grapheme
      Ghostty.PTY.write(pty, grapheme)

      assert {:ok, output} = wait_for_screen_text(pty, terminal, typed, output, @input_timeout_ms)

      {:ok, screen} = Terminal.snapshot(terminal, :plain)
      assert_textarea_shape!(screen)
      assert String.contains?(screen, typed)

      {typed, output}
    end)
    |> elem(1)
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

  defp wait_for_screen_text(pty, terminal, text, output, timeout) do
    wait_for_screen(pty, terminal, &String.contains?(&1, text), output, timeout)
  end

  defp wait_for_screen(pty, terminal, predicate, output, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_screen(pty, terminal, predicate, output, deadline)
  end

  defp do_wait_for_screen(pty, terminal, predicate, output, deadline) do
    receive do
      {:data, data} ->
        Terminal.write(terminal, data)
        {:ok, screen} = Terminal.snapshot(terminal, :plain)
        output = IO.iodata_to_binary([output, data])

        if predicate.(screen) do
          {:ok, output}
        else
          do_wait_for_screen(pty, terminal, predicate, output, deadline)
        end

      {:pty_write, data} ->
        Ghostty.PTY.write(pty, data)
        do_wait_for_screen(pty, terminal, predicate, output, deadline)

      {:exit, status} ->
        {:exit, status, output}
    after
      remaining_timeout(deadline) ->
        {:ok, screen} = Terminal.snapshot(terminal, :plain)
        {:error, {:screen_predicate_timeout, screen, output}}
    end
  end

  defp wait_for_exit(output, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_exit(output, deadline)
  end

  defp do_wait_for_exit(output, deadline) do
    receive do
      {:data, data} ->
        do_wait_for_exit(IO.iodata_to_binary([output, data]), deadline)

      {:pty_write, _data} ->
        do_wait_for_exit(output, deadline)

      {:exit, status} ->
        {:exit, status, output}
    after
      remaining_timeout(deadline) -> {:error, {:exit_timeout, output}}
    end
  end

  defp remaining_timeout(deadline) do
    max(deadline - System.monotonic_time(:millisecond), 0)
  end

  defp last_item([item]), do: item
  defp last_item([_item | items]), do: last_item(items)
end
