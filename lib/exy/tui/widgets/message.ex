defmodule Exy.TUI.Widgets.Message do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Markdown, Theme}
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
    blank = block_line("", width, theme, bg_key, fg_key)

    [
      blank
      | Exy.TUI.Lines.append(
          Enum.map(lines, &block_line(&1, width, theme, bg_key, fg_key)),
          blank
        )
    ]
  end

  defp block_line(line, width, theme, bg_key, fg_key) do
    background = IO.iodata_to_binary(Theme.bg_start(theme, bg_key))
    reset = IO.ANSI.reset()

    content =
      line |> then(&Theme.fg(theme, fg_key, &1)) |> keep_background_after_resets(background)

    content_width = Exy.TUI.Width.visible_length(line)
    right_padding = String.duplicate(" ", max(width - content_width - 2, 0))

    [background, "  ", content, right_padding, reset]
  end

  defp keep_background_after_resets(content, background) do
    content
    |> IO.iodata_to_binary()
    |> String.replace(IO.ANSI.reset(), IO.ANSI.reset() <> background)
  end

  defp prefix_first_line([first | rest], prefix), do: [[prefix, first] | rest]
end
