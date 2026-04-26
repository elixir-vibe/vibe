defmodule Exy.TUI.Widgets.Autocomplete do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget, Width}
  alias Exy.UI.Autocomplete

  @impl true
  def render(%{props: props}, width, theme) do
    autocomplete = Autocomplete.new(props)
    inner_width = max(width - 4, 1)

    header = header(autocomplete, inner_width, theme)

    rows =
      autocomplete.items
      |> Enum.take(autocomplete.limit)
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        row(item, index == autocomplete.selected, inner_width, theme)
      end)

    rows = if rows == [], do: [empty_row(autocomplete, inner_width, theme)], else: rows

    [frame_line(header, width, theme) | Enum.map(rows, &frame_line(&1, width, theme))]
  end

  defp header(%Autocomplete{title: nil, query: ""}, _width, theme),
    do: Theme.fg(theme, :dim, "Completions")

  defp header(%Autocomplete{title: title, query: ""}, _width, theme),
    do: Theme.fg(theme, :accent, title)

  defp header(%Autocomplete{title: title, query: query}, width, theme) do
    title = title || "Completions"

    Widget.fit_line(
      [Theme.fg(theme, :accent, title), Theme.fg(theme, :dim, ["  ", query])],
      width
    )
  end

  defp row(item, selected?, width, theme) do
    marker = if selected?, do: Theme.fg(theme, :accent, "›"), else: Theme.fg(theme, :dim, " ")
    label = if selected?, do: Theme.bold(item.label), else: item.label
    detail = detail(item.detail, width, theme)
    line = Widget.join_sides([marker, " ", label], detail, width)

    if selected? do
      Theme.bg(theme, :selected_bg, Widget.pad_line(line, width))
    else
      Widget.pad_line(line, width)
    end
  end

  defp detail(nil, _width, _theme), do: ""

  defp detail(detail, width, theme),
    do: theme |> Theme.fg(:dim, detail) |> Width.take(div(width, 2))

  defp empty_row(%Autocomplete{empty_message: message}, width, theme) do
    message = message || "No matches"
    theme |> Theme.fg(:dim, message) |> Widget.pad_line(width)
  end

  defp frame_line(content, width, theme) do
    line = Widget.pad_line(["  ", content], max(width - 2, 0))
    Theme.bg(theme, :input_bg, line)
  end
end
