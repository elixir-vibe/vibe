defmodule Exy.TUI.Widgets.SelectList do
  @moduledoc "TUI widget: navigable selection list."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    title = Map.get(props, :title)
    items = Map.get(props, :items, [])
    selected = Map.get(props, :selected, 0)
    limit = Map.get(props, :limit, 8)
    offset = viewport_offset(length(items), selected, limit)

    header = if title, do: [Theme.fg(theme, :accent, title)], else: []

    rows =
      items
      |> Enum.slice(offset, limit)
      |> Enum.with_index(offset)
      |> Enum.map(fn {item, index} -> row(item, index == selected, width, theme) end)

    Exy.TUI.Lines.join(header, rows)
  end

  defp row(item, selected?, width, theme) do
    marker = if selected?, do: Theme.symbol(theme, :success_icon), else: " "
    label = item_label(item)
    detail = item_detail(item)
    line = Widget.join_sides([marker, " ", label], Theme.fg(theme, :dim, detail), width)

    if selected? do
      Theme.bg(theme, :selected_bg, Widget.pad_line(line, width))
    else
      line
    end
  end

  defp item_label(%{label: label}), do: label
  defp item_label(%{name: name}), do: name
  defp item_label(%{value: value}), do: value
  defp item_label(item), do: to_string(item)

  defp item_detail(%{detail: detail}) when is_binary(detail), do: detail
  defp item_detail(_item), do: ""

  defp viewport_offset(count, selected, limit) do
    cond do
      count <= limit -> 0
      selected < limit -> 0
      true -> min(selected - limit + 1, count - limit)
    end
  end
end
