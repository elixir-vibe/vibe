defmodule Vibe.TUI.Widgets.Confirmation do
  @moduledoc "TUI widget: yes/no confirmation dialog."
  @behaviour Vibe.TUI.Widget

  alias Vibe.Support.Lists
  alias Vibe.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    title = Map.get(props, :title, "Confirm?")
    message = Map.get(props, :message)
    items = Map.get(props, :items, ["Yes", "No"])
    selected = Map.get(props, :selected, 0)

    [Widget.inset_line(Theme.fg(theme, :accent, title), width)]
    |> Lists.join(message_lines(message, width, theme))
    |> Lists.join([""])
    |> Lists.join(option_lines(items, selected, width, theme))
  end

  defp message_lines(nil, _width, _theme), do: []

  defp message_lines(message, width, theme) do
    message
    |> to_string()
    |> String.split("\n")
    |> Enum.map(fn line -> Widget.inset_line(Theme.fg(theme, :text, line), width) end)
  end

  defp option_lines(items, selected, width, theme) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> option_line(item, index == selected, width, theme) end)
  end

  defp option_line(item, selected?, width, theme) do
    marker = if selected?, do: "→", else: " "
    color = if selected?, do: :accent, else: :text
    Widget.inset_line(Theme.fg(theme, color, [marker, " ", to_string(item)]), width)
  end
end
