defmodule Exy.TUI.Runtime do
  @moduledoc """
  Startable terminal runtime for Exy's interactive TUI.
  """

  alias Exy.TUI.TerminalLoop

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
        receive_events(tty, loop)
      after
        write_output([
          end_synchronized_update(),
          enable_autowrap(),
          show_cursor(),
          IO.ANSI.reset()
        ])

        GenServer.stop(tty)
      end
    end
  end

  defp receive_events(tty, loop) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]}}} ->
        :ok

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape}}} ->
        :ok

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        repaint_or_stop(tty, loop)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        TerminalLoop.resize(loop, columns, rows)
        repaint_or_stop(tty, loop)

      {TerminalLoop, :event, _event} ->
        repaint_or_stop(tty, loop)

      {Ghostty.TTY, ^tty, :eof} ->
        :ok
    end
  end

  defp repaint_or_stop(tty, loop) do
    case drain_pending_events(tty, loop) do
      :continue ->
        render(tty, loop)
        receive_events(tty, loop)

      :stop ->
        :ok
    end
  end

  defp drain_pending_events(tty, loop) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]}}} ->
        :stop

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape}}} ->
        :stop

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        drain_pending_events(tty, loop)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        drain_pending_events(tty, loop)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        TerminalLoop.resize(loop, columns, rows)
        drain_pending_events(tty, loop)

      {TerminalLoop, :event, _event} ->
        drain_pending_events(tty, loop)

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
      IO.ANSI.home(),
      IO.ANSI.clear()
    ]

    rows =
      lines
      |> Enum.with_index(start_row)
      |> Enum.map(fn {line, row} -> [IO.ANSI.cursor(row, 1), IO.ANSI.clear_line(), line] end)

    finish = [
      end_synchronized_update(),
      IO.ANSI.cursor(cursor_row, cursor_column),
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
