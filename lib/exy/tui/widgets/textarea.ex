defmodule Exy.TUI.Widgets.Textarea do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}
  alias Exy.TUI.Widgets.Frame

  @impl true
  def render(%{props: props}, width, theme) do
    title = Map.get(props, :title, "Message")
    value = Map.get(props, :value, "") || ""
    placeholder = Map.get(props, :placeholder, "Ask Exy...")
    cursor = Map.get(props, :cursor, String.length(value))
    focused? = Map.get(props, :focused?, true)
    min_rows = Map.get(props, :min_rows, 3)
    max_rows = Map.get(props, :max_rows, 8)
    inner_width = max(width - 4, 1)

    body =
      value
      |> textarea_lines(placeholder, cursor, focused?, inner_width, theme)
      |> pad_rows(min_rows, max_rows)
      |> Enum.map(&Frame.line(&1, width, theme))

    [Frame.border(theme, width, :dialog_top_left, :dialog_top_right, title)]
    |> Exy.TUI.Lines.join(body)
    |> Exy.TUI.Lines.append(Frame.border(theme, width, :dialog_bottom_left, :dialog_bottom_right))
  end

  defp textarea_lines("", placeholder, _cursor, _focused?, width, theme) do
    theme |> Theme.fg(:input_placeholder, placeholder) |> Widget.wrap(width)
  end

  defp textarea_lines(value, _placeholder, cursor, focused?, width, theme) do
    value
    |> with_cursor(cursor, focused?, theme)
    |> Widget.wrap(width)
  end

  defp with_cursor(content, _cursor, false, theme), do: Theme.fg(theme, :input_text, content)

  defp with_cursor(content, cursor, true, theme) do
    cursor = cursor |> max(0) |> min(String.length(content))
    {left, right} = String.split_at(content, cursor)

    cursor_part =
      case String.next_grapheme(right) do
        nil ->
          Theme.bg(
            theme,
            :input_cursor_bg,
            Theme.fg(theme, :input_cursor, Theme.symbol(theme, :input_cursor))
          )

        {grapheme, _rest} ->
          Theme.bg(theme, :input_cursor_bg, Theme.fg(theme, :input_cursor, grapheme))
      end

    rest = if right == "", do: "", else: String.slice(right, 1..-1//1)
    [Theme.fg(theme, :input_text, left), cursor_part, Theme.fg(theme, :input_text, rest)]
  end

  defp pad_rows(lines, min_rows, max_rows) do
    rows = Enum.take(lines, max_rows)
    Exy.TUI.Lines.join(rows, List.duplicate("", max(min_rows - length(rows), 0)))
  end
end
