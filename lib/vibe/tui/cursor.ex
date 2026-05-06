defmodule Vibe.TUI.Cursor do
  @moduledoc "Calculates terminal cursor coordinates for rendered TUI frames."

  alias Vibe.TUI.{Widget, Width}

  @spec editor_position(map(), non_neg_integer()) :: {pos_integer(), pos_integer()}
  def editor_position(snapshot, editor_start_row) when is_map(snapshot) do
    inner_width = max(snapshot.width - 4, 1)
    text = snapshot.editor.text || ""
    cursor = snapshot.editor.cursor || 0
    before_cursor = String.slice(text, 0, cursor)
    logical_lines = String.split(before_cursor, "\n")
    {previous_lines, current_line} = split_current_line(logical_lines)

    previous_rows =
      previous_lines
      |> Enum.map(&(&1 |> Widget.wrap(inner_width) |> length()))
      |> Enum.sum()

    current_width = Width.visible_length(current_line)

    row = editor_start_row + 2 + previous_rows + div(current_width, inner_width)
    column = 3 + rem(current_width, inner_width)

    {max(row, 1), max(column, 1)}
  end

  defp split_current_line([]), do: {[], ""}
  defp split_current_line([line]), do: {[], line}

  defp split_current_line([line | lines]) do
    {previous, current} = split_current_line(lines)
    {[line | previous], current}
  end
end
