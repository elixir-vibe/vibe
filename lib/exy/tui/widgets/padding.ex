defmodule Exy.TUI.Widgets.Padding do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Widget

  @impl true
  def render(%{props: props, children: children}, width, theme) do
    x = Map.get(props, :x, Map.get(props, :horizontal, 1))
    y = Map.get(props, :y, Map.get(props, :vertical, 0))
    inner_width = max(width - x * 2, 1)
    blank = String.duplicate(" ", width)

    body =
      children
      |> Enum.flat_map(&Widget.render(&1, inner_width, theme))
      |> Enum.map(&Widget.pad_line([String.duplicate(" ", x), &1], width))

    List.duplicate(blank, y) ++ body ++ List.duplicate(blank, y)
  end
end
