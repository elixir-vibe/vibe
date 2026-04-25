defmodule Exy.TUI.Widgets.Message do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Markdown, Theme, Widget}
  alias Exy.TUI.Widgets.Loader

  @impl true
  def render(%{props: %{role: :user, text: text}}, width, theme) do
    safe_render(width, theme, fn -> render_user(text, width, theme) end)
  end

  def render(%{props: %{error: error}}, width, theme) when is_binary(error) do
    safe_render(width, theme, fn ->
      error
      |> to_string()
      |> Markdown.render(max(width - 4, 1), theme)
      |> prefix_first_line(Theme.fg(theme, :error, "ERROR "))
      |> render_block_lines(width, theme, :tool_error_bg, :error)
    end)
  end

  def render(%{props: %{role: :assistant} = props}, width, theme) do
    safe_render(width, theme, fn ->
      render_assistant(Map.get(props, :text), width, theme, Map.get(props, :loader_phase, 0))
    end)
  end

  def render(%{props: %{text: text}}, width, theme) do
    safe_render(width, theme, fn -> render_user(text, width, theme) end)
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

  defp safe_render(width, theme, fun) do
    fun.()
  rescue
    error -> render_failure(width, theme, Exception.format(:error, error, __STACKTRACE__))
  catch
    kind, reason -> render_failure(width, theme, Exception.format(kind, reason, __STACKTRACE__))
  end

  defp render_failure(width, theme, error) do
    error
    |> String.split("\n")
    |> Enum.flat_map(&Widget.wrap(Theme.fg(theme, :error, &1), max(width - 4, 1)))
    |> prefix_first_line(Theme.fg(theme, :error, "RENDER ERROR "))
    |> render_block_lines(width, theme, :tool_error_bg, :error)
  end

  defp prefix_first_line([first | rest], prefix), do: [[prefix, first] | rest]
end
