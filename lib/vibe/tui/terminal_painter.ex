defmodule Vibe.TUI.TerminalPainter do
  @moduledoc """
  Pure terminal-diff state machine for Vibe's TUI runtime.

  Receives fully rendered semantic lines and a cursor position in document
  coordinates. Returns iodata to write to the terminal plus updated state.

  Three render paths:

  - **First paint** — writes all lines, creating native terminal scrollback.
  - **Viewport shift** — scrolls via `\\r\\n` then repaints the visible area.
  - **In-place patch** — rewrites only changed lines within the current viewport.
  """

  alias IO.ANSI

  defstruct lines: [],
            cursor: {1, 1},
            width: 80,
            height: 24,
            hardware_row: 1,
            viewport_top: 1

  @type t :: %__MODULE__{
          lines: [IO.chardata()],
          cursor: {pos_integer(), pos_integer()},
          width: pos_integer(),
          height: pos_integer(),
          hardware_row: pos_integer(),
          viewport_top: pos_integer()
        }

  @spec new(pos_integer(), pos_integer()) :: t()
  def new(width, height), do: %__MODULE__{width: width, height: height}

  @spec resize(t(), pos_integer(), pos_integer()) :: t()
  def resize(%__MODULE__{width: width} = painter, width, height),
    do: %{painter | height: height}

  def resize(%__MODULE__{} = painter, width, height) do
    %{
      painter
      | lines: [],
        cursor: {1, 1},
        width: width,
        height: height,
        hardware_row: 1,
        viewport_top: 1
    }
  end

  @spec force_full_redraw(t()) :: t()
  def force_full_redraw(%__MODULE__{} = painter) do
    %{painter | lines: [], cursor: {1, 1}, hardware_row: 1, viewport_top: 1}
  end

  @spec render(t(), [IO.chardata()], {pos_integer(), pos_integer()}) :: {IO.chardata(), t()}
  def render(%__MODULE__{} = painter, lines, cursor) do
    padded = pad_to_height(lines, painter.height)
    cursor = shift_cursor(cursor, length(padded) - length(lines))
    do_render(padded, cursor, painter)
  end

  @spec cleanup() :: IO.chardata()
  def cleanup, do: [sync_end(), autowrap_on(), cursor_show(), ANSI.reset()]

  # -- Render dispatch --------------------------------------------------------

  defp do_render(lines, cursor, %{lines: []} = painter) do
    vt = viewport_top(lines, painter.height)

    frame = wrap_frame(write_lines(lines))

    {frame ++ [position_cursor(cursor, vt)], commit(painter, lines, cursor, vt)}
  end

  defp do_render(lines, cursor, painter) do
    case changed_range(painter.lines, lines) do
      nil ->
        vt = viewport_top(lines, painter.height)
        {[position_cursor(cursor, vt)], commit(painter, lines, cursor, vt)}

      {first, last} ->
        vt = viewport_top(lines, painter.height)

        if vt != painter.viewport_top do
          scroll_and_repaint(lines, cursor, painter, vt)
        else
          patch_in_place(lines, cursor, painter, first, last)
        end
    end
  end

  # -- Viewport shifted: scroll then repaint full visible area ----------------

  defp scroll_and_repaint(lines, cursor, painter, desired_vt) do
    scroll = desired_vt - painter.viewport_top
    visible = viewport_slice(lines, desired_vt, painter.height)

    body =
      if scroll > 0 do
        [
          move_to_screen_row(painter, painter.height),
          String.duplicate("\r\n", scroll),
          ANSI.cursor(1, 1),
          write_cleared_lines(visible)
        ]
      else
        [ANSI.cursor(1, 1), write_cleared_lines(visible)]
      end

    frame = wrap_frame(body)
    {frame ++ [position_cursor(cursor, desired_vt)], commit(painter, lines, cursor, desired_vt)}
  end

  # -- Same viewport: patch only changed lines --------------------------------

  defp patch_in_place(lines, cursor, painter, first, last) do
    target = first + 1
    {move, vt} = navigate_to_row(painter, target)
    vt = max(vt, viewport_top(lines, painter.height))
    count = last - first + 1

    body = [
      move,
      "\r",
      lines |> slice_with_padding(first, count) |> write_cleared_lines()
    ]

    frame = wrap_frame(body)
    {frame ++ [position_cursor(cursor, vt)], commit(painter, lines, cursor, vt)}
  end

  # -- Frame helpers ----------------------------------------------------------

  defp wrap_frame(body),
    do: [sync_begin(), cursor_hide(), autowrap_off() | List.wrap(body)] ++ [sync_end()]

  defp position_cursor({row, col}, vt),
    do: [ANSI.cursor(max(row - vt + 1, 1), col), autowrap_on(), cursor_show()]

  defp write_lines(lines), do: Enum.intersperse(lines, "\r\n")

  defp write_cleared_lines(lines),
    do: Enum.map_intersperse(lines, "\r\n", &[ANSI.clear_line(), &1])

  # -- State ------------------------------------------------------------------

  defp commit(painter, lines, cursor, vt) do
    %{
      painter
      | lines: lines,
        cursor: cursor,
        hardware_row: elem(cursor, 0),
        viewport_top: vt
    }
  end

  # -- Viewport ---------------------------------------------------------------

  defp viewport_top(lines, height), do: max(length(lines) - height + 1, 1)
  defp viewport_slice(lines, vt, height), do: Enum.slice(lines, (vt - 1)..(vt + height - 2)//1)

  defp pad_to_height(lines, height) do
    padding = max(height - length(lines), 0)
    Vibe.TUI.Lines.join(List.duplicate("", padding), lines)
  end

  defp shift_cursor({row, col}, offset), do: {row + offset, col}

  defp slice_with_padding(lines, start, count) do
    slice = Enum.slice(lines, start, count)
    Vibe.TUI.Lines.join(slice, List.duplicate("", count - length(slice)))
  end

  # -- Diff -------------------------------------------------------------------

  defp changed_range(old, new) do
    case first_diff(old, new, 0) do
      nil ->
        nil

      first ->
        max_len = max(length(old), length(new))
        tail = matching_tail(Enum.reverse(old), Enum.reverse(new), max(max_len - first - 1, 0), 0)
        {first, max_len - tail - 1}
    end
  end

  defp first_diff([], [], _i), do: nil
  defp first_diff([], _new, i), do: i
  defp first_diff(_old, [], i), do: i
  defp first_diff([h | a], [h | b], i), do: first_diff(a, b, i + 1)
  defp first_diff(_old, _new, i), do: i

  defp matching_tail(_old, _new, 0, n), do: n
  defp matching_tail([], _new, _r, n), do: n
  defp matching_tail(_old, [], _r, n), do: n
  defp matching_tail([h | a], [h | b], r, n), do: matching_tail(a, b, r - 1, n + 1)
  defp matching_tail(_old, _new, _r, n), do: n

  # -- Cursor navigation -----------------------------------------------------

  defp navigate_to_row(painter, target) do
    bottom = painter.viewport_top + painter.height - 1

    if target > bottom do
      scroll = target - bottom

      {[move_to_screen_row(painter, painter.height), String.duplicate("\r\n", scroll)],
       painter.viewport_top + scroll}
    else
      from = painter.hardware_row - painter.viewport_top + 1
      to = target - painter.viewport_top + 1
      {cursor_move(from, to), painter.viewport_top}
    end
  end

  defp move_to_screen_row(painter, target_screen_row) do
    current = (painter.hardware_row - painter.viewport_top + 1) |> max(1) |> min(painter.height)
    cursor_move(current, target_screen_row)
  end

  defp cursor_move(from, to) when to > from, do: ANSI.cursor_down(to - from)
  defp cursor_move(from, to) when to < from, do: ANSI.cursor_up(from - to)
  defp cursor_move(_from, _to), do: []

  # -- Terminal escape sequences ----------------------------------------------

  defp cursor_hide, do: "\e[?25l"
  defp cursor_show, do: "\e[?25h"
  defp autowrap_off, do: "\e[?7l"
  defp autowrap_on, do: "\e[?7h"
  defp sync_begin, do: "\e[?2026h"
  defp sync_end, do: "\e[?2026l"
end
