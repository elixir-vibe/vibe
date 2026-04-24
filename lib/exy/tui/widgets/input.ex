defmodule Exy.TUI.Widgets.Input do
  @moduledoc false

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
      |> display_text(placeholder, theme)
      |> with_cursor(cursor, focused?, theme)
      |> Widget.fit_line(content_width)
      |> Widget.pad_line(content_width)

    [Theme.bg(theme, :input_bg, [prefix, content])]
  end

  defp display_text("", placeholder, theme), do: Theme.fg(theme, :input_placeholder, placeholder)
  defp display_text(value, _placeholder, theme), do: Theme.fg(theme, :input_text, value)

  defp with_cursor(content, _cursor, false, _theme), do: content

  defp with_cursor(content, cursor, true, theme) do
    text = IO.iodata_to_binary(content)
    cursor = cursor |> max(0) |> min(String.length(text))
    {left, right} = String.split_at(text, cursor)

    case String.next_grapheme(right) do
      nil ->
        [
          left,
          Theme.bg(
            theme,
            :input_cursor_bg,
            Theme.fg(theme, :input_cursor, Theme.symbol(theme, :input_cursor))
          )
        ]

      {grapheme, rest} ->
        [left, Theme.bg(theme, :input_cursor_bg, Theme.fg(theme, :input_cursor, grapheme)), rest]
    end
  end
end
