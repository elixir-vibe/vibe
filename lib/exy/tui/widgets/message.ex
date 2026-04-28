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
      render_assistant(
        Map.get(props, :text),
        width,
        theme,
        Map.get(props, :loader_phase, 0),
        Map.get(props, :loader_label)
      )
    end)
  end

  def render(%{props: %{role: :subagent} = props}, width, theme) do
    safe_render(width, theme, fn -> render_subagent(props, width, theme) end)
  end

  def render(%{props: %{text: text}}, width, theme) do
    safe_render(width, theme, fn -> render_user(text, width, theme) end)
  end

  defp render_user(text, width, theme) do
    render_block(text, width, theme, :user_message_bg, :user_message_text)
  end

  defp render_subagent(props, width, theme) do
    title = subagent_title(props, theme)
    details = subagent_details(props)

    [title | details]
    |> render_block_lines(width, theme, :tool_pending_bg, :text)
  end

  defp subagent_title(props, theme) do
    lifecycle = Map.get(props, :lifecycle, :started)
    status = Map.get(props, :status)

    role =
      props
      |> Map.get(:role_name, Map.get(props, :role_label, Map.get(props, :role)))
      |> role_name()

    icon = Theme.fg(theme, :tool_icon, Theme.symbol(theme, :tool_icon))
    label = if lifecycle == :finished, do: "finished", else: "started"
    suffix = if status, do: " · #{status}", else: ""

    [icon, " subagent ", role, " ", label, suffix]
  end

  defp subagent_details(props) do
    [
      detail_line("task", Map.get(props, :task)),
      detail_line("session", Map.get(props, :child_session_id)),
      detail_line("attach", attach_command(Map.get(props, :child_session_id))),
      detail_line("error", Map.get(props, :error))
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp detail_line(_label, nil), do: nil
  defp detail_line(_label, ""), do: nil
  defp detail_line(label, value), do: ["  ", label, ": ", to_string(value)]

  defp attach_command(session_id) when is_binary(session_id), do: "exy a #{session_id}"
  defp attach_command(_session_id), do: nil

  defp role_name(:subagent), do: "worker"
  defp role_name(nil), do: "worker"
  defp role_name(role), do: to_string(role)

  defp render_assistant(text, width, theme, loader_phase, loader_label) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      Loader.render(
        %{props: %{label: loader_label || "Thinking", phase: loader_phase}},
        width,
        theme
      )
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
    Widget.block_lines(lines, width, theme, bg_key, fg: fg_key, padding_left: 2)
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
