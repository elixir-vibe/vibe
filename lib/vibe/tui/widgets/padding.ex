defmodule Vibe.TUI.Widgets.Padding do
  @moduledoc "TUI widget: padding wrapper."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.{Lines, Widget}

  @impl true
  def render(%{props: props, children: children}, width, theme) do
    x = Map.get(props, :x, Map.get(props, :horizontal, 1))
    y = Map.get(props, :y, Map.get(props, :vertical, 0))
    inner_width = max(width - x * 2, 1)
    blank = Widget.spaces(width)

    blanks = List.duplicate(blank, y)

    body =
      children
      |> Enum.flat_map(&Widget.render(&1, inner_width, theme))
      |> Enum.map(&Widget.pad_line([Widget.spaces(x), &1], width))

    body
    |> Lines.join(blanks)
    |> then(&Lines.join(blanks, &1))
  end
end
