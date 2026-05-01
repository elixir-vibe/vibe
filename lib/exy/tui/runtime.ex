defmodule Exy.TUI.Runtime do
  @moduledoc """
  Startable terminal runtime for Exy's interactive TUI.
  """

  alias Exy.TUI.{RuntimeSupervisor, TerminalLoop, TerminalPainter}
  alias IO.ANSI

  @interrupt_repeat_window_ms 1_500

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    {columns, rows} = Ghostty.TTY.size()

    opts =
      opts
      |> Keyword.put_new(:width, columns)
      |> Keyword.put_new(:height, rows)
      |> Keyword.put(:output, false)
      |> Keyword.put(:event_target, self())

    runtime_id = make_ref()
    opts = Keyword.put(opts, :runtime_id, runtime_id)

    with :ok <- ensure_interactive_terminal(),
         {:ok, supervisor} <- RuntimeSupervisor.start_link(opts) do
      run_with_tty(supervisor, runtime_id, columns, rows)
    end
  end

  defp run_with_tty(supervisor, runtime_id, columns, rows) do
    case Ghostty.TTY.start_link(owner: self(), takeover: true) do
      {:ok, tty} ->
        loop = RuntimeSupervisor.name(runtime_id, TerminalLoop)

        try do
          painter = render(loop, TerminalPainter.new(columns, rows))
          receive_events(tty, loop, nil, painter)
        after
          write_output(TerminalPainter.cleanup())
          GenServer.stop(tty)
          Supervisor.stop(supervisor)
        end

      {:error, reason} ->
        Supervisor.stop(supervisor)
        {:error, reason}
    end
  end

  defp receive_events(tty, loop, last_interrupt_at, painter) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}} ->
        handle_interrupt(tty, loop, event, last_interrupt_at, painter)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}} ->
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, last_interrupt_at, painter)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, nil, painter)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        repaint_or_stop(tty, loop, nil, painter)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        {painter, _changed?} = resize_painter(loop, painter, {columns, rows})
        repaint_or_stop(tty, loop, nil, painter)

      {TerminalLoop, :event, _event} ->
        repaint_or_stop(tty, loop, last_interrupt_at, painter)

      {Ghostty.TTY, ^tty, :eof} ->
        :ok
    end
  end

  defp repaint_or_stop(tty, loop, last_interrupt_at, painter) do
    case drain_pending_events(tty, loop, last_interrupt_at, painter) do
      {:continue, painter} ->
        painter = render(loop, painter)
        receive_events(tty, loop, last_interrupt_at, painter)

      :stop ->
        :ok
    end
  end

  defp handle_interrupt(tty, loop, event, last_interrupt_at, painter) do
    now = System.monotonic_time(:millisecond)

    if recent_interrupt?(last_interrupt_at, now) do
      :ok
    else
      TerminalLoop.input_key(loop, event)
      repaint_or_stop(tty, loop, now, painter)
    end
  end

  defp recent_interrupt?(last_interrupt_at, now \\ System.monotonic_time(:millisecond))
  defp recent_interrupt?(nil, _now), do: false

  defp recent_interrupt?(last_interrupt_at, now),
    do: now - last_interrupt_at <= @interrupt_repeat_window_ms

  defp drain_pending_events(tty, loop, last_interrupt_at, painter) do
    deadline = System.monotonic_time(:millisecond) + 8
    drain_pending_events(tty, loop, last_interrupt_at, painter, deadline, 0)
  end

  defp drain_pending_events(tty, loop, last_interrupt_at, painter, deadline, drained) do
    if drained >= 25 or System.monotonic_time(:millisecond) >= deadline do
      {:continue, painter}
    else
      receive do
        {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}} ->
          if recent_interrupt?(last_interrupt_at) do
            :stop
          else
            TerminalLoop.input_key(loop, event)

            drain_pending_events(
              tty,
              loop,
              System.monotonic_time(:millisecond),
              painter,
              deadline,
              drained + 1
            )
          end

        {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}} ->
          TerminalLoop.input_key(loop, event)
          drain_pending_events(tty, loop, last_interrupt_at, painter, deadline, drained + 1)

        {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
          TerminalLoop.input_key(loop, event)
          drain_pending_events(tty, loop, nil, painter, deadline, drained + 1)

        {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
          TerminalLoop.input(loop, data)
          drain_pending_events(tty, loop, nil, painter, deadline, drained + 1)

        {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
          {painter, _changed?} = resize_painter(loop, painter, {columns, rows})
          drain_pending_events(tty, loop, nil, painter, deadline, drained + 1)

        {TerminalLoop, :event, _event} ->
          drain_pending_events(tty, loop, last_interrupt_at, painter, deadline, drained + 1)

        {Ghostty.TTY, ^tty, :eof} ->
          :stop
      after
        0 -> {:continue, painter}
      end
    end
  end

  @doc """
  Resizes the terminal loop and painter when the terminal dimensions change.
  """
  def resize_painter(
        _loop,
        %TerminalPainter{width: columns, height: rows} = painter,
        {columns, rows}
      ),
      do: {painter, false}

  def resize_painter(loop, %TerminalPainter{} = painter, {columns, rows}) do
    TerminalLoop.resize(loop, columns, rows)
    {TerminalPainter.resize(painter, columns, rows), true}
  end

  defp render(loop, painter) do
    {lines, cursor} = TerminalLoop.render_snapshot(loop)
    {frame, painter} = TerminalPainter.render(painter, lines, cursor)
    write_output(frame)
    painter
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
