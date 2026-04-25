defmodule Exy.TUI.Widgets.Message do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Markdown, Theme, Widget}
  alias Exy.TUI.Widgets.Loader

  @impl true
  def render(%{props: %{role: :user, text: text}}, width, theme) do
    render_user(text, width, theme)
  end

  def render(%{props: %{error: error}}, width, theme) when is_binary(error) do
    error
    |> to_string()
    |> Markdown.render(width, theme)
    |> prefix_first_line(Theme.fg(theme, :error, "ERROR "))
  end

  def render(%{props: %{role: :assistant} = props}, width, theme) do
    render_assistant(Map.get(props, :text), width, theme, Map.get(props, :loader_phase, 0))
  end

  def render(%{props: %{text: text}}, width, theme) do
    render_user(text, width, theme)
  end

  defp render_user(text, width, theme) do
    inner_width = max(width - 4, 1)
    blank = user_message_line("", width, theme)

    lines =
      text
      |> to_string()
      |> Markdown.render(inner_width, theme)
      |> Enum.map(&user_message_line(&1, width, theme))

    [blank | Exy.TUI.Lines.append(lines, blank)]
  end

  defp user_message_line(line, width, theme) do
    line = Theme.fg(theme, :user_message_text, line)

    ["  ", line]
    |> Widget.pad_line(width)
    |> then(&Theme.bg(theme, :user_message_bg, &1))
  end

  defp render_assistant(text, width, theme, loader_phase) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      Loader.render(%{props: %{label: "Thinking", phase: loader_phase}}, width, theme)
    else
      Markdown.render(text, width, theme)
    end
  end

  defp prefix_first_line([first | rest], prefix), do: [[prefix, first] | rest]
end
