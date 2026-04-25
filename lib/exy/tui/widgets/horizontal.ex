defmodule Exy.TUI.Widgets.Horizontal do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Widget

  @impl true
  def render(%{children: children}, width, theme) do
    children
    |> Enum.map(&Widget.render(&1, width, theme))
    |> join_columns(width)
  end

  defp join_columns([], _width), do: []

  defp join_columns(columns, width) do
    height = columns |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)
    gap = 2
    count = length(columns)
    total_gap = gap * max(count - 1, 0)
    column_width = max(div(width - total_gap, count), 1)

    for row <- 0..(height - 1) do
      columns
      |> Enum.map(fn lines ->
        Enum.at(lines, row, "") |> Widget.fit_line(column_width) |> Widget.pad_line(column_width)
      end)
      |> Enum.intersperse(Widget.spaces(gap))
      |> Widget.fit_line(width)
    end
  end
end
