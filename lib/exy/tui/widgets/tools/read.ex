defmodule Exy.TUI.Widgets.Tools.Read do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Lines, Markdown, TextTruncation, Theme, ToolWidget, Widget}
  alias Exy.TUI.Widgets.Tools.FileTool

  @impl true
  def render(tool, width, theme) do
    result = ToolWidget.output(tool)

    ToolWidget.block(tool, width, theme,
      name: :read,
      summary: FileTool.path_summary(tool, result),
      params?: false,
      output_lines: output_lines(tool, result, max(width - 2, 1), theme)
    )
  end

  defp output_lines(_tool, %{error: error}, width, theme),
    do: ToolWidget.error_lines(error, width, theme)

  defp output_lines(tool, %{content: content} = result, width, theme) when is_binary(content) do
    truncation =
      content
      |> String.split("\n")
      |> TextTruncation.lines(enabled?: Map.get(tool, :truncate?, true), limit: 8)

    content_lines =
      if markdown?(result) do
        truncation.lines
        |> Enum.join("\n")
        |> Markdown.render(max(width - 2, 1), theme)
        |> Enum.map(&[Widget.spaces(2), &1])
        |> maybe_append_render_hint(truncation, theme, width)
      else
        truncation.lines
        |> Enum.flat_map(fn line ->
          line = display_line(line, width)
          ToolWidget.output_line(highlight(line, Map.get(result, :language), theme), width)
        end)
        |> maybe_append_render_hint(truncation, theme, width)
      end

    footer = truncation_footer(result, theme)

    if footer == [] do
      content_lines
    else
      content_lines |> Lines.join([""]) |> Lines.join(footer)
    end
  end

  defp output_lines(_tool, value, width, theme), do: ToolWidget.plain_lines(value, width, theme)

  defp maybe_append_render_hint(lines, %{truncated?: false}, _theme, _width), do: lines

  defp maybe_append_render_hint(lines, %{omitted: omitted}, theme, width) do
    lines
    |> Lines.join([""])
    |> Lines.join([TextTruncation.hint(omitted, theme, width)])
  end

  defp truncation_footer(result, theme) do
    omitted_lines = Map.get(result, :omitted_lines, 0)
    omitted_bytes = Map.get(result, :omitted_bytes, 0)

    cond do
      omitted_lines > 0 ->
        [[Widget.spaces(2), Theme.fg(theme, :muted, "… (#{omitted_lines} more lines)")]]

      omitted_bytes > 0 ->
        [[Widget.spaces(2), Theme.fg(theme, :muted, "… (#{omitted_bytes} more bytes)")]]

      true ->
        []
    end
  end

  defp markdown?(%{language: language}) when is_binary(language),
    do: language in ["markdown", "md"]

  defp markdown?(%{path: path}) when is_binary(path),
    do: String.downcase(Path.extname(path)) in [".md", ".markdown"]

  defp markdown?(_result), do: false

  defp display_line(line, width) do
    limit = max(width * 2, 200)
    shortened = String.slice(line, 0, limit)
    if byte_size(shortened) < byte_size(line), do: shortened <> "…", else: line
  end

  defp highlight(line, language, theme) when language in [nil, ""],
    do: Theme.fg(theme, :tool_output, line)

  defp highlight(line, language, theme) do
    {:ok, highlighted} = Lumis.highlight(line, formatter: {:terminal, language: language})
    highlighted
  rescue
    _error -> Theme.fg(theme, :tool_output, line)
  end
end
