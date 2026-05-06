defmodule Vibe.TUI.Widgets.ListPanel do
  @moduledoc "Shared framed list panel used by TUI pickers and autocomplete."

  alias Vibe.TUI.{Theme, Widget, Width}

  @spec render(map(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render(props, width, theme) do
    inner_width = max(width - 4, 1)
    items = Map.get(props, :items, [])
    selected = Map.get(props, :selected, 0)
    limit = Map.get(props, :limit, 8)
    offset = Map.get(props, :offset, 0)

    rows =
      items
      |> Enum.slice(offset, limit)
      |> Enum.with_index(offset)
      |> Enum.map(fn {item, index} -> row(item, index == selected, inner_width, theme) end)

    rows =
      if rows == [],
        do: [empty_row(Map.get(props, :empty_message), inner_width, theme)],
        else: rows

    panel_lines = [
      frame_line(header(props, inner_width, theme), width, theme),
      blank_line(width, theme)
    ]

    panel_lines = panel_lines ++ Enum.map(rows, &frame_line(&1, width, theme))

    case Map.get(props, :chrome, :full) do
      :compact -> panel_lines
      :full -> [blank_line(width, theme) | panel_lines]
    end
  end

  defp header(%{title: nil, query: ""}, _width, theme), do: Theme.fg(theme, :dim, "Completions")
  defp header(%{title: title, query: ""}, _width, theme), do: Theme.fg(theme, :accent, title)

  defp header(props, width, theme) do
    title = Map.get(props, :title) || "Completions"
    query = Map.get(props, :query, "")

    Widget.fit_line(
      [Theme.fg(theme, :accent, title), Theme.fg(theme, :dim, ["  ", query])],
      width
    )
  end

  defp row(item, selected?, width, theme) do
    marker = if selected?, do: Theme.fg(theme, :accent, "›"), else: Theme.fg(theme, :dim, " ")
    label = if selected?, do: Theme.bold(item_label(item)), else: item_label(item)
    detail = item |> item_detail() |> detail(width, theme)
    line = Widget.join_sides([marker, " ", label], detail, width)

    if selected? do
      Theme.bg(theme, :selected_bg, Widget.pad_line(line, width))
    else
      Widget.pad_line(line, width)
    end
  end

  defp detail(nil, _width, _theme), do: ""
  defp detail("", _width, _theme), do: ""

  defp detail(detail, width, theme),
    do: theme |> Theme.fg(:dim, detail) |> Width.take(div(width, 2))

  defp empty_row(message, width, theme) do
    message = message || "No matches"
    theme |> Theme.fg(:dim, message) |> Widget.pad_line(width)
  end

  defp blank_line(width, theme), do: Widget.background_line("", width, theme, :input_bg)

  defp frame_line(content, width, theme) do
    line = Widget.pad_line(["  ", content], max(width - 2, 0))
    Widget.background_line(line, width, theme, :input_bg)
  end

  defp item_label(%{label: label}), do: label
  defp item_label(%{name: name}), do: name
  defp item_label(%{value: value}), do: value
  defp item_label(item), do: to_string(item)

  defp item_detail(%{detail: detail}) when is_binary(detail), do: detail
  defp item_detail(_item), do: ""
end
