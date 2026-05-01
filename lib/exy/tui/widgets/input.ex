defmodule Exy.TUI.Widgets.Input do
  @moduledoc "Internal implementation module."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget, Width}

  @impl true
  def render(%{props: props}, width, theme) do
    prompt = Map.get(props, :prompt, Theme.symbol(theme, :input_prompt))
    value = Map.get(props, :value, "") || ""
    placeholder = Map.get(props, :placeholder, "Ask Exy...")
    cursor = Map.get(props, :cursor, String.length(value))
    focused? = Map.get(props, :focused?, true)

    prefix = [Theme.fg(theme, :input_prompt, prompt), " "]
    content_width = max(width - Width.visible_length(prefix), 1)

    content =
      value
      |> display_text(placeholder, cursor, focused?, theme)
      |> Widget.fit_line(content_width)
      |> Widget.pad_line(content_width)

    [Theme.bg(theme, :input_bg, [prefix, content])]
  end

  defp display_text("", placeholder, _cursor, false, theme) do
    Theme.fg(theme, :input_placeholder, placeholder)
  end

  defp display_text("", placeholder, _cursor, true, theme) do
    [
      cursor_cell(Theme.symbol(theme, :input_cursor), theme),
      Theme.fg(theme, :input_placeholder, placeholder)
    ]
  end

  defp display_text(value, _placeholder, _cursor, false, theme),
    do: Theme.fg(theme, :input_text, value)

  defp display_text(value, _placeholder, cursor, true, theme) do
    cursor = cursor |> max(0) |> min(String.length(value))
    {left, right} = String.split_at(value, cursor)

    case String.next_grapheme(right) do
      nil ->
        [
          Theme.fg(theme, :input_text, left),
          cursor_cell(Theme.symbol(theme, :input_cursor), theme)
        ]

      {grapheme, rest} ->
        [
          Theme.fg(theme, :input_text, left),
          cursor_cell(grapheme, theme),
          Theme.fg(theme, :input_text, rest)
        ]
    end
  end

  defp cursor_cell(grapheme, theme) do
    Theme.bg(theme, :input_cursor_bg, Theme.fg(theme, :input_cursor, grapheme))
  end
end
