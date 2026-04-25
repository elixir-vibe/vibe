defmodule Exy.TUI.RuntimeTest do
  use ExUnit.Case, async: false

  @cols 100
  @rows 30
  @startup_timeout_ms 10_000
  @input_timeout_ms 1_000
  @exit_timeout_ms 5_000

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
    assert {:ok, terminal} = Ghostty.Terminal.start_link(cols: @cols, rows: @rows)
    {lines, cursor} = rendered_textarea("")
    start_row = @rows - length(lines) + 1

    Ghostty.Terminal.write(terminal, Exy.TUI.Runtime.render_frame(lines, cursor, start_row))

    {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
    render_state = Ghostty.Terminal.render_state(terminal)
    screen_lines = String.split(screen, "\n")

    assert Enum.at(screen_lines, start_row - 1) |> String.starts_with?("~/")
    assert Enum.at(screen_lines, start_row) |> String.starts_with?("╭")
    assert List.last(screen_lines) |> String.starts_with?("╰")
    assert {render_state.cursor.y + 1, render_state.cursor.x + 1} == cursor
    refute Enum.any?(Enum.slice(screen_lines, 0, start_row - 1), &String.contains?(&1, "Prompt"))
  end

  test "render frame leaves terminal content and cursor stable after every typed character" do
    assert {:ok, terminal} = Ghostty.Terminal.start_link(cols: @cols, rows: @rows)
    text = "hello world this is a long prompt that wraps across textarea rows"

    Enum.reduce(String.graphemes(text), "", fn grapheme, typed ->
      typed = typed <> grapheme
      {lines, cursor} = rendered_textarea(typed)

      start_row = @rows - length(lines) + 1
      Ghostty.Terminal.write(terminal, Exy.TUI.Runtime.render_frame(lines, cursor, start_row))

      {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
      render_state = Ghostty.Terminal.render_state(terminal)

      assert_textarea_shape!(screen)
      assert String.contains?(screen, typed)
      assert render_state.cursor.visible
      assert {render_state.cursor.y + 1, render_state.cursor.x + 1} == cursor

      typed
    end)
  end

  test "mix exy accepts input in a real PTY, escape cancels, and double ctrl-c exits" do
    {:ok, terminal} = Ghostty.Terminal.start_link(cols: @cols, rows: @rows)

    {:ok, pty} =
      Ghostty.PTY.start_link(
        cmd: "/bin/sh",
        args: ["-lc", "cd #{File.cwd!()} && mix exy"],
        cols: @cols,
        rows: @rows,
        reader_start_timeout: 5_000
      )

    try do
      assert {:ok, _output} = wait_for_screen_text(pty, terminal, "Exy", "", @startup_timeout_ms)

      assert {:ok, output} = wait_for_screen_text(pty, terminal, "╯", "", @input_timeout_ms)

      type_and_assert_stable_frames(pty, terminal, "abc wraps across the prompt", output)

      {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
      render_state = Ghostty.Terminal.render_state(terminal)

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
    end
  end

  defp type_and_assert_stable_frames(pty, terminal, text, output) do
    text
    |> String.graphemes()
    |> Enum.reduce({"", output}, fn grapheme, {typed, output} ->
      typed = typed <> grapheme
      Ghostty.PTY.write(pty, grapheme)

      assert {:ok, output} = wait_for_screen_text(pty, terminal, typed, output, @input_timeout_ms)
      assert {:ok, output} = wait_for_screen_text(pty, terminal, "╯", output, @input_timeout_ms)

      {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
      assert_textarea_shape!(screen)
      assert String.contains?(screen, typed)

      {typed, output}
    end)
    |> elem(1)
  end

  defp rendered_textarea(text) do
    {:ok, loop} =
      Exy.TUI.TerminalLoop.start_link(
        width: @cols,
        height: @rows,
        output: false,
        ask_fun: fn _prompt -> "" end
      )

    Exy.TUI.TerminalLoop.input(loop, text)
    {Exy.TUI.TerminalLoop.render(loop), Exy.TUI.TerminalLoop.cursor_position(loop)}
  end

  defp assert_textarea_shape!(screen) do
    lines = String.split(screen, "\n")

    top = Enum.find(lines, &String.starts_with?(&1, "╭"))
    bottom = Enum.find(lines, &String.starts_with?(&1, "╰"))
    body = Enum.filter(lines, &(String.starts_with?(&1, "│") and String.ends_with?(&1, "│")))

    assert top && String.ends_with?(top, "╮")
    assert bottom && String.ends_with?(bottom, "╯")
    assert length(body) >= 3
  end

  defp wait_for_screen_text(pty, terminal, text, output, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_screen_text(pty, terminal, text, output, deadline)
  end

  defp do_wait_for_screen_text(pty, terminal, text, output, deadline) do
    receive do
      {:data, data} ->
        Ghostty.Terminal.write(terminal, data)
        {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
        output = IO.iodata_to_binary([output, data])

        if String.contains?(screen, text) do
          {:ok, output}
        else
          do_wait_for_screen_text(pty, terminal, text, output, deadline)
        end

      {:pty_write, data} ->
        Ghostty.PTY.write(pty, data)
        do_wait_for_screen_text(pty, terminal, text, output, deadline)

      {:exit, status} ->
        {:exit, status, output}
    after
      remaining_timeout(deadline) ->
        {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
        {:error, {:missing_text, text, screen, output}}
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
end
