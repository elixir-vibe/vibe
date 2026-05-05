defmodule Exy.TUI.TerminalPainter do
  @moduledoc """
  Pure terminal-diff state machine for Exy's TUI runtime.

  The painter receives fully rendered semantic lines and a cursor position in
  document coordinates. It returns iodata to write to the terminal plus updated
  painter state. Runtime owns IO; this module owns terminal positioning logic.
  """

  alias IO.ANSI

  defstruct lines: [],
            cursor: {1, 1},
            width: 80,
            height: 24,
            hardware_row: 1,
            viewport_top: 1,
            clear_scrollback?: false

  @type t :: %__MODULE__{
          lines: [IO.chardata()],
          cursor: {pos_integer(), pos_integer()},
          width: pos_integer(),
          height: pos_integer(),
          hardware_row: pos_integer(),
          viewport_top: pos_integer(),
          clear_scrollback?: boolean()
        }

  @spec new(pos_integer(), pos_integer()) :: t()
  def new(width, height), do: %__MODULE__{width: width, height: height}

  @spec resize(t(), pos_integer(), pos_integer()) :: t()
  def resize(%__MODULE__{width: width} = painter, width, height) do
    %{painter | height: height}
  end

  def resize(%__MODULE__{} = painter, width, height) do
    %{
      painter
      | lines: [],
        cursor: {1, 1},
        width: width,
        height: height,
        hardware_row: 1,
        viewport_top: 1,
        clear_scrollback?: true
    }
  end

  @spec render(t(), [IO.chardata()], {pos_integer(), pos_integer()}) :: {IO.chardata(), t()}
  def render(%__MODULE__{} = painter, lines, cursor) do
    padded_lines = pad_to_viewport(lines, painter.height)
    cursor = pad_cursor(cursor, length(padded_lines) - length(lines))
    render_native(padded_lines, cursor, painter)
  end

  @spec cleanup() :: IO.chardata()
  def cleanup do
    [end_synchronized_update(), enable_autowrap(), show_cursor(), ANSI.reset()]
  end

  defp render_native(lines, cursor, %{lines: []} = painter) do
    viewport_top = viewport_top(lines, painter.height)
    screen_cursor = screen_cursor(cursor, viewport_top)

    frame = [
      begin_synchronized_update(),
      hide_cursor(),
      disable_autowrap(),
      ANSI.clear(),
      ANSI.home(),
      maybe_clear_scrollback(painter),
      intersperse_lines(lines),
      end_synchronized_update(),
      ANSI.cursor(elem(screen_cursor, 0), elem(screen_cursor, 1)),
      enable_autowrap(),
      show_cursor()
    ]

    {frame, put_render_state(painter, lines, cursor, viewport_top)}
  end

  defp render_native(lines, cursor, painter) do
    desired_viewport_top = viewport_top(lines, painter.height)

    case changed_range(painter.lines, lines) do
      nil ->
        screen_cursor = screen_cursor(cursor, desired_viewport_top)
        frame = [ANSI.cursor(elem(screen_cursor, 0), elem(screen_cursor, 1))]
        {frame, put_render_state(painter, lines, cursor, desired_viewport_top)}

      _range when desired_viewport_top != painter.viewport_top ->
        render_native(lines, cursor, %{painter | lines: []})

      {first, _last} when first + 1 < painter.viewport_top ->
        render_native(lines, cursor, %{painter | lines: []})

      {first, last} ->
        patch_lines(lines, cursor, painter, first, last)
    end
  end

  defp patch_lines(lines, cursor, painter, first, last) do
    target_row = first + 1
    {move, viewport_top} = move_to_row(painter, target_row)

    viewport_top =
      max(
        viewport_top,
        min(viewport_top(lines, painter.height), max(last + 2 - painter.height, 1))
      )

    screen_cursor = screen_cursor(cursor, viewport_top)

    patch_count = last - first + 1

    frame = [
      begin_synchronized_update(),
      hide_cursor(),
      disable_autowrap(),
      move,
      "\r",
      lines
      |> replacement_lines(first, patch_count)
      |> Enum.map_intersperse("\r\n", &[ANSI.clear_line(), &1]),
      end_synchronized_update(),
      ANSI.cursor(elem(screen_cursor, 0), elem(screen_cursor, 1)),
      enable_autowrap(),
      show_cursor()
    ]

    {frame, put_render_state(painter, lines, cursor, viewport_top)}
  end

  defp replacement_lines(lines, first, count) do
    replacement = Enum.slice(lines, first, count)
    Exy.TUI.Lines.join(replacement, List.duplicate("", count - length(replacement)))
  end

  defp put_render_state(painter, lines, cursor, viewport_top) do
    %{
      painter
      | lines: lines,
        cursor: cursor,
        hardware_row: elem(cursor, 0),
        viewport_top: viewport_top,
        clear_scrollback?: false
    }
  end

  defp changed_range(old, new) do
    case first_changed_index(old, new, 0) do
      nil ->
        nil

      first ->
        max_length = max(length(old), length(new))
        max_tail = max(max_length - first - 1, 0)
        tail = common_tail_length(Enum.reverse(old), Enum.reverse(new), max_tail, 0)
        {first, max_length - tail - 1}
    end
  end

  defp first_changed_index([], [], _index), do: nil
  defp first_changed_index([], _new, index), do: index
  defp first_changed_index(_old, [], index), do: index

  defp first_changed_index([old_line | old], [new_line | new], index) do
    if old_line == new_line do
      first_changed_index(old, new, index + 1)
    else
      index
    end
  end

  defp common_tail_length(_old, _new, 0, count), do: count
  defp common_tail_length([], _new, _remaining, count), do: count
  defp common_tail_length(_old, [], _remaining, count), do: count

  defp common_tail_length([old_line | old], [new_line | new], remaining, count) do
    if old_line == new_line do
      common_tail_length(old, new, remaining - 1, count + 1)
    else
      count
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

  defp move_to_row(painter, target_row) do
    bottom = painter.viewport_top + painter.height - 1

    if target_row > bottom do
      current_screen_row =
        (painter.hardware_row - painter.viewport_top + 1) |> max(1) |> min(painter.height)

      move_to_bottom = painter.height - current_screen_row
      scroll = target_row - bottom

      {[move_from_to(1, move_to_bottom + 1), String.duplicate("\r\n", scroll)],
       painter.viewport_top + scroll}
    else
      current_screen_row = painter.hardware_row - painter.viewport_top + 1
      target_screen_row = target_row - painter.viewport_top + 1
      {move_from_to(current_screen_row, target_screen_row), painter.viewport_top}
    end
  end

  defp move_from_to(from, to) when to > from, do: ANSI.cursor_down(to - from)
  defp move_from_to(from, to) when to < from, do: ANSI.cursor_up(from - to)
  defp move_from_to(_from, _to), do: []

  defp maybe_clear_scrollback(%{clear_scrollback?: true}), do: clear_scrollback()
  defp maybe_clear_scrollback(_painter), do: []

  defp hide_cursor, do: "\e[?25l"
  defp show_cursor, do: "\e[?25h"
  defp disable_autowrap, do: "\e[?7l"
  defp enable_autowrap, do: "\e[?7h"
  defp begin_synchronized_update, do: "\e[?2026h"
  defp end_synchronized_update, do: "\e[?2026l"

  # IO.ANSI does not expose ED 3. CSI 3 J is the terminal control for clearing scrollback.
  defp clear_scrollback, do: "\e[3J"
end
