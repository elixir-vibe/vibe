defmodule Exy.TUI.Widgets.Notifications do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    props
    |> Map.get(:items, [])
    |> Enum.map(&line(&1, width, theme))
  end

  defp line(%{level: level, text: text}, width, theme) do
    color = level_color(level)
    icon = level_icon(level, theme)
    Widget.fit_line([Theme.fg(theme, color, icon), " ", text], width)
  end

  defp line(text, width, theme),
    do: Widget.fit_line([Theme.symbol(theme, :status_icon), " ", to_string(text)], width)

  defp level_color(:error), do: :error
  defp level_color(:warning), do: :warning
  defp level_color(:success), do: :success
  defp level_color(_level), do: :accent

  defp level_icon(:error, theme), do: Theme.symbol(theme, :error_icon)
  defp level_icon(:warning, theme), do: Theme.symbol(theme, :warning_icon)
  defp level_icon(:success, theme), do: Theme.symbol(theme, :success_icon)
  defp level_icon(_level, theme), do: Theme.symbol(theme, :status_icon)
end
