defmodule Exy.TUI.Runtime do
  @moduledoc """
  Startable terminal runtime for Exy's interactive TUI.
  """

  alias Exy.TUI.TerminalLoop
  alias IO.ANSI

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    {columns, rows} = Ghostty.TTY.size()

    opts =
      opts
      |> Keyword.put_new(:width, columns)
      |> Keyword.put_new(:height, rows)
      |> Keyword.put(:output, false)
      |> Keyword.put(:event_target, self())

    with :ok <- ensure_interactive_terminal(),
         {:ok, loop} <- TerminalLoop.start_link(opts),
         {:ok, tty} <- Ghostty.TTY.start_link(owner: self(), takeover: true) do
      try do
        render(tty, loop)
        receive_events(tty, loop, nil)
      after
        write_output([
          end_synchronized_update(),
          enable_autowrap(),
          show_cursor(),
          ANSI.reset()
        ])

        GenServer.stop(tty)
      end
    end
  end

  defp receive_events(tty, loop, last_interrupt_at) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}} ->
        handle_interrupt(tty, loop, event, last_interrupt_at)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}} ->
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, last_interrupt_at)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, nil)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        repaint_or_stop(tty, loop, nil)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        TerminalLoop.resize(loop, columns, rows)
        repaint_or_stop(tty, loop, nil)

      {TerminalLoop, :event, _event} ->
        repaint_or_stop(tty, loop, last_interrupt_at)

      {Ghostty.TTY, ^tty, :eof} ->
        :ok
    end
  end

  defp repaint_or_stop(tty, loop, last_interrupt_at) do
    case drain_pending_events(tty, loop, last_interrupt_at) do
      :continue ->
        render(tty, loop)
        receive_events(tty, loop, last_interrupt_at)

      :stop ->
        :ok
    end
  end

  defp handle_interrupt(tty, loop, event, last_interrupt_at) do
    now = System.monotonic_time(:millisecond)

    if recent_interrupt?(last_interrupt_at, now) do
      :ok
    else
      TerminalLoop.input_key(loop, event)
      repaint_or_stop(tty, loop, now)
    end
  end

  defp recent_interrupt?(last_interrupt_at, now \\ System.monotonic_time(:millisecond))
  defp recent_interrupt?(nil, _now), do: false
  defp recent_interrupt?(last_interrupt_at, now), do: now - last_interrupt_at <= 1_500

  defp drain_pending_events(tty, loop, last_interrupt_at) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}} ->
        if recent_interrupt?(last_interrupt_at) do
          :stop
        else
          TerminalLoop.input_key(loop, event)
          drain_pending_events(tty, loop, System.monotonic_time(:millisecond))
        end

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}} ->
        TerminalLoop.input_key(loop, event)
        drain_pending_events(tty, loop, last_interrupt_at)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        drain_pending_events(tty, loop, nil)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        drain_pending_events(tty, loop, nil)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        TerminalLoop.resize(loop, columns, rows)
        drain_pending_events(tty, loop, nil)

      {TerminalLoop, :event, _event} ->
        drain_pending_events(tty, loop, last_interrupt_at)

      {Ghostty.TTY, ^tty, :eof} ->
        :stop
    after
      0 -> :continue
    end
  end

  defp render(_tty, loop) do
    lines = TerminalLoop.render(loop)
    {cursor_row, cursor_column} = TerminalLoop.cursor_position(loop)
    start_row = max(TerminalLoop.viewport_height(loop) - length(lines) + 1, 1)

    write_output(render_frame(lines, {cursor_row, cursor_column}, start_row))
  end

  @doc "Builds a complete synchronized terminal repaint frame."
  @spec render_frame([IO.chardata()], {pos_integer(), pos_integer()}, pos_integer()) ::
          IO.chardata()
  def render_frame(lines, cursor, start_row \\ 1) do
    render_chunks(lines, cursor, start_row)
  end

  @doc "Builds ordered repaint chunks used by `render_frame/2` and regression tests."
  @spec render_chunks([IO.chardata()], {pos_integer(), pos_integer()}, pos_integer()) :: [
          IO.chardata()
        ]
  def render_chunks(lines, {cursor_row, cursor_column}, start_row \\ 1) do
    start = [
      begin_synchronized_update(),
      hide_cursor(),
      disable_autowrap(),
      ANSI.home(),
      ANSI.clear()
    ]

    rows =
      lines
      |> Enum.with_index(start_row)
      |> Enum.map(fn {line, row} -> [ANSI.cursor(row, 1), ANSI.clear_line(), line] end)

    finish = [
      end_synchronized_update(),
      ANSI.cursor(cursor_row, cursor_column),
      enable_autowrap(),
      show_cursor()
    ]

    [start | rows] |> Exy.TUI.Lines.append(finish)
  end

  defp hide_cursor, do: "\e[?25l"
  defp show_cursor, do: "\e[?25h"
  defp disable_autowrap, do: "\e[?7l"
  defp enable_autowrap, do: "\e[?7h"
  defp begin_synchronized_update, do: "\e[?2026h"
  defp end_synchronized_update, do: "\e[?2026l"

  defp write_output(data), do: IO.write(:stdio, data)

  defp ensure_interactive_terminal do
    if :prim_tty.isatty(:stdin) do
      :ok
    else
      {:error, :stdio_is_not_a_terminal}
    end
  end
end
