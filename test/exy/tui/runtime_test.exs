defmodule Exy.TUI.RuntimeTest do
  use ExUnit.Case, async: false

  @cols 100
  @rows 30
  @startup_timeout_ms 10_000
  @input_timeout_ms 1_000
  @exit_timeout_ms 5_000

  test "mix exy accepts input in a real PTY and exits with escape" do
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

      Ghostty.PTY.write(pty, "abc")
      assert {:ok, _output} = wait_for_screen_text(pty, terminal, "abc", "", @input_timeout_ms)

      {:ok, screen} = Ghostty.Terminal.snapshot(terminal, :plain)
      render_state = Ghostty.Terminal.render_state(terminal)

      refute String.contains?(screen, "BREAK:")
      assert render_state.cursor.visible

      Ghostty.PTY.write(pty, <<27>>)
      assert {:exit, 0, _output} = wait_for_exit("", @exit_timeout_ms)
    after
      if Process.alive?(pty), do: Ghostty.PTY.close(pty)
    end
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
