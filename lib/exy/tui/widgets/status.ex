defmodule Exy.TUI.Widgets.Status do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    icon = Map.get(props, :icon, Theme.symbol(theme, :status_icon))
    title = Map.get(props, :title, "")
    description = Map.get(props, :description, "")
    extra = Map.get(props, :extra, "")
    color = Map.get(props, :color, :accent)

    line = [
      Theme.fg(theme, color, icon),
      " ",
      Theme.fg(theme, color, title),
      gap(description),
      description,
      gap(extra),
      Theme.fg(theme, :dim, extra)
    ]

    [Widget.fit_line(line, width)]
  end

  defp gap(""), do: ""
  defp gap(nil), do: ""
  defp gap(_value), do: " "
end
