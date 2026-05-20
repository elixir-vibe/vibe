defmodule Vibe.TUI.Widgets.Horizontal do
  @moduledoc "TUI widget: horizontal layout container."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.Widget

  @impl true
  def render(%{children: children}, width, theme) do
    children
    |> Enum.map(&Widget.render(&1, width, theme))
    |> join_columns(width)
  end

  defp join_columns([], _width), do: []

  defp join_columns(columns, width) do
    height = columns |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)

    if height == 0 do
      []
    else
      join_columns(columns, width, height)
    end
  end

  defp join_columns(columns, width, height) do
    gap = 2
    count = length(columns)
    total_gap = gap * max(count - 1, 0)
    column_width = max(div(width - total_gap, count), 1)

    padded_columns = Enum.map(columns, &pad_column(&1, height))

    for row <- 0..(height - 1) do
      padded_columns
      |> Enum.map(fn lines ->
        lines
        |> array_get(row, "")
        |> Widget.fit_line(column_width)
        |> Widget.pad_line(column_width)
      end)
      |> Enum.intersperse(Widget.spaces(gap))
      |> Widget.fit_line(width)
    end
  end

  defp array_get(array, index, default) do
    if index < :array.size(array), do: :array.get(index, array), else: default
  end

  defp pad_column(lines, height) do
    lines
    |> Kernel.++(List.duplicate("", max(height - length(lines), 0)))
    |> :array.from_list()
  end
end
