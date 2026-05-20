defmodule Vibe.E2E.TUI.RuntimeTest do
  use ExUnit.Case, async: false

  alias Ghostty.Terminal

  @moduletag :integration

  @cols 100
  @rows 30
  @startup_timeout_ms 20_000
  @input_timeout_ms 1_000
  @exit_timeout_ms 5_000
  @reader_start_timeout_ms 5_000

  @tag timeout: 30_000
  test "mix vibe accepts input in a real PTY, escape cancels, and double ctrl-c exits" do
    {:ok, terminal} = Terminal.start_link(cols: @cols, rows: @rows)

    vibe_home =
      Path.join(System.tmp_dir!(), "vibe-runtime-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(vibe_home)

    {:ok, pty} =
      Ghostty.PTY.start_link(
        cmd: "/bin/sh",
        args: [
          "-lc",
          "cd #{File.cwd!()} && MIX_ENV=test VIBE_HOME=#{shell_quote(vibe_home)} mix vibe"
        ],
        cols: @cols,
        rows: @rows,
        reader_start_timeout: @reader_start_timeout_ms
      )

    try do
      assert {:ok, _output} = wait_for_screen_text(pty, terminal, "Vibe", "", @startup_timeout_ms)

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
      assert render_state.cursor.visible

      Ghostty.PTY.write(pty, <<27>>)
      assert {:error, {:exit_timeout, _output}} = wait_for_exit("", 300)

      Ghostty.PTY.write(pty, <<3>>)
      Process.sleep(50)
      Ghostty.PTY.write(pty, <<3>>)
      assert {:exit, 0, _output} = wait_for_exit("", @exit_timeout_ms)
    after
      if Process.alive?(pty), do: Ghostty.PTY.close(pty)
      File.rm_rf(vibe_home)
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
      assert String.contains?(screen, typed)

      {typed, output}
    end)
    |> elem(1)
  end

  defp textarea_shape?(screen) do
    lines = String.split(screen, "\n")

    top = Enum.find(lines, &String.starts_with?(&1, "╭"))
    bottom = Enum.find(lines, &String.starts_with?(&1, "╰"))
    body = Enum.filter(lines, &String.starts_with?(&1, "│"))

    top && bottom && length(body) >= 3
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
end
