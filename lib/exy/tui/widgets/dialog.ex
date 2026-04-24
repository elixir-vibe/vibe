defmodule Exy.TUI.Widgets.Dialog do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props, children: children}, width, theme) do
    title = Map.fetch!(props, :title)
    inner_width = max(width - 4, 1)

    border =
      Theme.fg(
        theme,
        :border,
        String.duplicate(Theme.symbol(theme, :dialog_horizontal), inner_width)
      )

    title_line =
      Widget.fit_line(
        [Theme.symbol(theme, :dialog_top_left), border, Theme.symbol(theme, :dialog_top_right)],
        width
      )

    heading =
      Widget.fit_line(
        [
          Theme.symbol(theme, :dialog_vertical),
          " ",
          Theme.fg(theme, :accent, title),
          String.duplicate(" ", inner_width),
          " ",
          Theme.symbol(theme, :dialog_vertical)
        ],
        width
      )

    body =
      children
      |> Enum.flat_map(&Exy.TUI.Widget.render(&1, inner_width, theme))
      |> Enum.map(
        &Widget.fit_line(
          [
            Theme.symbol(theme, :dialog_vertical),
            " ",
            &1,
            String.duplicate(" ", inner_width),
            " ",
            Theme.symbol(theme, :dialog_vertical)
          ],
          width
        )
      )

    bottom =
      Widget.fit_line(
        [
          Theme.symbol(theme, :dialog_bottom_left),
          border,
          Theme.symbol(theme, :dialog_bottom_right)
        ],
        width
      )

    [title_line, heading | body] ++ [bottom]
  end
end
