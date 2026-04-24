defmodule Exy.TUI.Widgets.Box do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props, children: children}, width, theme) do
    title = Map.get(props, :title)
    inner_width = max(width - 4, 1)
    horizontal = Theme.symbol(theme, :dialog_horizontal)
    border_width = max(width - 2, 0)

    top = border(theme, :dialog_top_left, :dialog_top_right, horizontal, border_width, title)

    body =
      children
      |> Enum.flat_map(&Widget.render(&1, inner_width, theme))
      |> Enum.map(&Widget.frame_line(&1, width, theme))

    bottom =
      border(theme, :dialog_bottom_left, :dialog_bottom_right, horizontal, border_width, nil)

    [top | body] ++ [bottom]
  end

  defp border(theme, left_key, right_key, horizontal, width, nil) do
    [
      Theme.symbol(theme, left_key),
      Theme.fg(theme, :border, String.duplicate(horizontal, width)),
      Theme.symbol(theme, right_key)
    ]
  end

  defp border(theme, left_key, right_key, horizontal, width, title) do
    title = [" ", Theme.fg(theme, :accent, title), " "]
    title_width = Exy.TUI.Width.visible_length(IO.iodata_to_binary(title))
    remaining = max(width - title_width, 0)

    [
      Theme.symbol(theme, left_key),
      Theme.fg(theme, :border, String.duplicate(horizontal, div(remaining, 2))),
      title,
      Theme.fg(theme, :border, String.duplicate(horizontal, remaining - div(remaining, 2))),
      Theme.symbol(theme, right_key)
    ]
  end
end
