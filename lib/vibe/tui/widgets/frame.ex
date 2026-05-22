defmodule Vibe.TUI.Widgets.Frame do
  @moduledoc "TUI widget: titled frame with optional border."
  alias Vibe.TUI.{Node}
  alias Vibe.Terminal.{Theme, Width}
  alias Vibe.TUI.Widget

  @spec border(Theme.t(), pos_integer(), atom(), atom(), IO.chardata() | nil) :: IO.chardata()
  def border(theme, width, left_key, right_key, title \\ nil) do
    horizontal = Theme.symbol(theme, :dialog_horizontal)
    content_width = max(width - 2, 0)

    [
      Theme.fg(theme, :border, Theme.symbol(theme, left_key)),
      border_content(theme, horizontal, content_width, title),
      Theme.fg(theme, :border, Theme.symbol(theme, right_key))
    ]
    |> Widget.background_line(width, theme, :input_bg)
  end

  @spec line(IO.chardata(), pos_integer(), Theme.t()) :: IO.chardata()
  def line(content, width, theme), do: Widget.frame_line(content, width, theme)

  @spec body([Node.t() | IO.chardata()], pos_integer(), Theme.t()) :: [IO.chardata()]
  def body(children, width, theme) do
    inner_width = max(width - 4, 1)

    children
    |> Enum.flat_map(&Widget.render(&1, inner_width, theme))
    |> Enum.map(&line(&1, width, theme))
  end

  defp border_content(theme, horizontal, width, nil) do
    Theme.fg(theme, :border, String.duplicate(horizontal, width))
  end

  defp border_content(theme, horizontal, width, title) do
    title = [" ", Theme.fg(theme, :accent, title), " "]
    title_width = Width.visible_length(title)
    remaining = max(width - title_width, 0)

    left_width = div(remaining, 2)

    [
      Theme.fg(theme, :border, String.duplicate(horizontal, left_width)),
      title,
      Theme.fg(theme, :border, String.duplicate(horizontal, remaining - left_width))
    ]
  end
end
