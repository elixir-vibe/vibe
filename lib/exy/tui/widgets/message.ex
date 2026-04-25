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
    render_block(text, width, theme, :user_message_bg, :user_message_text)
  end

  defp render_assistant(text, width, theme, loader_phase) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      Loader.render(%{props: %{label: "Thinking", phase: loader_phase}}, width, theme)
    else
      text
      |> Markdown.render(max(width - 4, 1), theme)
      |> render_block_lines(width, theme, :assistant_message_bg, :assistant_message_text)
    end
  end

  defp render_block(text, width, theme, bg_key, fg_key) do
    text
    |> to_string()
    |> Markdown.render(max(width - 4, 1), theme)
    |> render_block_lines(width, theme, bg_key, fg_key)
  end

  defp render_block_lines(lines, width, theme, bg_key, fg_key) do
    opts = [fg: fg_key, padding_left: 2]
    blank = Widget.background_line("", width, theme, bg_key, opts)

    [
      blank
      | Exy.TUI.Lines.append(
          Enum.map(lines, &Widget.background_line(&1, width, theme, bg_key, opts)),
          blank
        )
    ]
  end

  defp prefix_first_line([first | rest], prefix), do: [[prefix, first] | rest]
end
