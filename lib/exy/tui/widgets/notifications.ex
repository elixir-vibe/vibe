defmodule Exy.TUI.Widgets.Notifications do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    props
    |> Map.get(:items, [])
    |> Enum.flat_map(&lines(&1, width, theme))
  end

  defp lines(%{level: level, text: text}, width, theme) do
    color = level_color(level)
    icon = level_icon(level, theme)

    [[Theme.fg(theme, color, icon), " ", text]]
    |> Widget.block_lines(width, theme, level_bg(level), fg: color, padding_left: 2)
  end

  defp lines(text, width, theme) do
    [[Theme.symbol(theme, :status_icon), " ", to_string(text)]]
    |> Widget.block_lines(width, theme, :tool_pending_bg, padding_left: 2)
  end

  defp level_bg(:error), do: :tool_error_bg
  defp level_bg(:warning), do: :tool_pending_bg
  defp level_bg(:success), do: :tool_success_bg
  defp level_bg(_level), do: :assistant_message_bg

  defp level_color(:error), do: :error
  defp level_color(:warning), do: :warning
  defp level_color(:success), do: :success
  defp level_color(_level), do: :accent

  defp level_icon(:error, theme), do: Theme.symbol(theme, :error_icon)
  defp level_icon(:warning, theme), do: Theme.symbol(theme, :warning_icon)
  defp level_icon(:success, theme), do: Theme.symbol(theme, :success_icon)
  defp level_icon(_level, theme), do: Theme.symbol(theme, :status_icon)
end
