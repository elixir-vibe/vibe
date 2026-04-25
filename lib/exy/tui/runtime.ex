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
        render_state = render(tty, loop, new_render_state(columns, rows))
        receive_events(tty, loop, nil, render_state)
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

  defp receive_events(tty, loop, last_interrupt_at, render_state) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}} ->
        handle_interrupt(tty, loop, event, last_interrupt_at, render_state)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}} ->
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, last_interrupt_at, render_state)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, nil, render_state)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        repaint_or_stop(tty, loop, nil, render_state)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        TerminalLoop.resize(loop, columns, rows)
        render_state = reset_render_state(render_state, columns, rows)
        repaint_or_stop(tty, loop, nil, render_state)

      {TerminalLoop, :event, _event} ->
        repaint_or_stop(tty, loop, last_interrupt_at, render_state)

      {Ghostty.TTY, ^tty, :eof} ->
        :ok
    end
  end

  defp repaint_or_stop(tty, loop, last_interrupt_at, render_state) do
    case drain_pending_events(tty, loop, last_interrupt_at, render_state) do
      {:continue, render_state} ->
        render_state = render(tty, loop, render_state)
        receive_events(tty, loop, last_interrupt_at, render_state)

      :stop ->
        :ok
    end
  end

  defp handle_interrupt(tty, loop, event, last_interrupt_at, render_state) do
    now = System.monotonic_time(:millisecond)

    if recent_interrupt?(last_interrupt_at, now) do
      :ok
    else
      TerminalLoop.input_key(loop, event)
      repaint_or_stop(tty, loop, now, render_state)
    end
  end

  defp recent_interrupt?(last_interrupt_at, now \\ System.monotonic_time(:millisecond))
  defp recent_interrupt?(nil, _now), do: false
  defp recent_interrupt?(last_interrupt_at, now), do: now - last_interrupt_at <= 1_500

  defp drain_pending_events(tty, loop, last_interrupt_at, render_state) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}} ->
        if recent_interrupt?(last_interrupt_at) do
          :stop
        else
          TerminalLoop.input_key(loop, event)
          drain_pending_events(tty, loop, System.monotonic_time(:millisecond), render_state)
        end

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}} ->
        TerminalLoop.input_key(loop, event)
        drain_pending_events(tty, loop, last_interrupt_at, render_state)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        TerminalLoop.input_key(loop, event)
        drain_pending_events(tty, loop, nil, render_state)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        TerminalLoop.input(loop, data)
        drain_pending_events(tty, loop, nil, render_state)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        TerminalLoop.resize(loop, columns, rows)
        drain_pending_events(tty, loop, nil, reset_render_state(render_state, columns, rows))

      {TerminalLoop, :event, _event} ->
        drain_pending_events(tty, loop, last_interrupt_at, render_state)

      {Ghostty.TTY, ^tty, :eof} ->
        :stop
    after
      0 -> {:continue, render_state}
    end
  end

  defp new_render_state(width, height),
    do: %{
      lines: [],
      cursor: {1, 1},
      width: width,
      height: height,
      hardware_row: 1,
      viewport_top: 1
    }

  defp reset_render_state(state, width, height),
    do: %{
      state
      | lines: [],
        cursor: {1, 1},
        width: width,
        height: height,
        hardware_row: 1,
        viewport_top: 1
    }

  defp render(_tty, loop, state) do
    lines = TerminalLoop.render_full(loop)
    cursor = TerminalLoop.full_cursor_position(loop)
    padded_lines = pad_to_viewport(lines, state.height)
    cursor = pad_cursor(cursor, length(padded_lines) - length(lines))

    {frame, state} = render_native(padded_lines, cursor, state)
    write_output(frame)
    state
  end

  defp render_native(lines, cursor, %{lines: []} = state) do
    viewport_top = viewport_top(lines, state.height)
    screen_cursor = screen_cursor(cursor, viewport_top)

    frame = [
      begin_synchronized_update(),
      hide_cursor(),
      disable_autowrap(),
      ANSI.clear(),
      ANSI.home(),
      intersperse_lines(lines),
      end_synchronized_update(),
      ANSI.cursor(elem(screen_cursor, 0), elem(screen_cursor, 1)),
      enable_autowrap(),
      show_cursor()
    ]

    {frame,
     %{
       state
       | lines: lines,
         cursor: cursor,
         hardware_row: elem(cursor, 0),
         viewport_top: viewport_top
     }}
  end

  defp render_native(lines, cursor, state) do
    case changed_range(state.lines, lines) do
      nil ->
        viewport_top = viewport_top(lines, state.height)
        screen_cursor = screen_cursor(cursor, viewport_top)

        {[ANSI.cursor(elem(screen_cursor, 0), elem(screen_cursor, 1))],
         %{state | cursor: cursor, hardware_row: elem(cursor, 0), viewport_top: viewport_top}}

      {first, _last} when first + 1 < state.viewport_top ->
        render_native(lines, cursor, %{state | lines: []})

      {first, last} ->
        patch_lines(lines, cursor, state, first, last)
    end
  end

  defp patch_lines(lines, cursor, state, first, last) do
    target_row = first + 1
    {move, viewport_top} = move_to_row(state, target_row)

    viewport_top =
      max(viewport_top, min(viewport_top(lines, state.height), max(last + 2 - state.height, 1)))

    screen_cursor = screen_cursor(cursor, viewport_top)

    frame = [
      begin_synchronized_update(),
      hide_cursor(),
      disable_autowrap(),
      move,
      "\r",
      lines
      |> Enum.slice(first..last//1)
      |> Enum.map_intersperse("\r\n", &[ANSI.clear_line(), &1]),
      end_synchronized_update(),
      ANSI.cursor(elem(screen_cursor, 0), elem(screen_cursor, 1)),
      enable_autowrap(),
      show_cursor()
    ]

    {frame,
     %{
       state
       | lines: lines,
         cursor: cursor,
         hardware_row: elem(cursor, 0),
         viewport_top: viewport_top
     }}
  end

  defp changed_range(old, new) do
    max_length = max(length(old), length(new))

    first =
      Enum.find(0..max(max_length - 1, 0), fn index ->
        Enum.at(old, index) != Enum.at(new, index)
      end)

    if is_nil(first) do
      nil
    else
      last =
        (max_length - 1)..first//-1
        |> Enum.find(fn index -> Enum.at(old, index) != Enum.at(new, index) end)

      {first, last}
    end
  end

  defp pad_to_viewport(lines, height) do
    padding = max(height - length(lines), 0)
    Exy.TUI.Lines.join(List.duplicate("", padding), lines)
  end

  defp pad_cursor({row, column}, padding), do: {row + padding, column}

  defp viewport_top(lines, height), do: max(length(lines) - height + 1, 1)

  defp screen_cursor({row, column}, viewport_top), do: {max(row - viewport_top + 1, 1), column}

  defp intersperse_lines(lines), do: Enum.intersperse(lines, "\r\n")

  defp move_to_row(state, target_row) do
    bottom = state.viewport_top + state.height - 1

    if target_row > bottom do
      current_screen_row =
        (state.hardware_row - state.viewport_top + 1) |> max(1) |> min(state.height)

      move_to_bottom = state.height - current_screen_row
      scroll = target_row - bottom

      {[ANSI.cursor_down(move_to_bottom), String.duplicate("\r\n", scroll)],
       state.viewport_top + scroll}
    else
      current_screen_row = state.hardware_row - state.viewport_top + 1
      target_screen_row = target_row - state.viewport_top + 1
      {move_from_to(current_screen_row, target_screen_row), state.viewport_top}
    end
  end

  defp move_from_to(from, to) when to > from, do: ANSI.cursor_down(to - from)
  defp move_from_to(from, to) when to < from, do: ANSI.cursor_up(from - to)
  defp move_from_to(_from, _to), do: []

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
