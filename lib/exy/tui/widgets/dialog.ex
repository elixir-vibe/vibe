defmodule Exy.TUI.Widgets.Dialog do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props, children: children}, width, theme) do
    title = Map.fetch!(props, :title)
    hint = Map.get(props, :hint)
    inner_width = max(width - 4, 1)
    horizontal = Theme.symbol(theme, :dialog_horizontal)

    top = [
      Theme.symbol(theme, :dialog_top_left),
      Theme.fg(theme, :border, String.duplicate(horizontal, max(width - 2, 0))),
      Theme.symbol(theme, :dialog_top_right)
    ]

    heading = Widget.frame_line(Theme.fg(theme, :accent, title), width, theme)

    body =
      children
      |> Enum.flat_map(&Widget.render(&1, inner_width, theme))
      |> Enum.map(&Widget.frame_line(&1, width, theme))

    hint_lines =
      if hint, do: [Widget.frame_line(Theme.fg(theme, :muted, hint), width, theme)], else: []

    bottom = [
      Theme.symbol(theme, :dialog_bottom_left),
      Theme.fg(theme, :border, String.duplicate(horizontal, max(width - 2, 0))),
      Theme.symbol(theme, :dialog_bottom_right)
    ]

    [top, heading] ++ body ++ hint_lines ++ [bottom]
  end
end
