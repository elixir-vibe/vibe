defmodule Vibe.TUI.Widgets.Tools.Read do
  @moduledoc "TUI tool widget: file read with syntax and images."
  @behaviour Vibe.TUI.ToolWidget

  alias Vibe.Model.Content
  alias Vibe.TUI.{Lines, Markdown, TextTruncation, Theme, ToolWidget, Widget}
  alias Vibe.TUI.Widgets.Image
  alias Vibe.TUI.Widgets.Tools.FileTool

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

  defp output_lines(_tool, %{content_type: :image, parts: parts}, width, theme)
       when is_list(parts) do
    Enum.flat_map(parts, fn
      %Content.Text{text: text} ->
        text
        |> String.split("\n")
        |> Enum.map(fn line ->
          ToolWidget.output_line(Theme.fg(theme, :tool_output, line), width)
        end)

      %Content.Image{} = image ->
        image_lines(image, width, theme)

      part ->
        ToolWidget.plain_lines(part, width, theme)
    end)
  end

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
        |> Enum.map(&display_line(&1, width))
        |> ToolWidget.source_lines(Map.get(result, :language), width, theme)
        |> maybe_append_render_hint(truncation, theme, width)
      end

    maybe_append_file_limit_footer(content_lines, truncation, result, theme)
  end

  defp output_lines(_tool, value, width, theme), do: ToolWidget.plain_lines(value, width, theme)

  defp image_lines(%Content.Image{} = image, width, theme) do
    image
    |> Image.new(max_width_cells: 80)
    |> Image.render(width, theme)
  end

  defp maybe_append_render_hint(lines, %{truncated?: false}, _theme, _width), do: lines

  defp maybe_append_render_hint(lines, %{omitted: omitted}, theme, width) do
    lines
    |> Lines.join([""])
    |> Lines.join([TextTruncation.hint(omitted, theme, width)])
  end

  defp maybe_append_file_limit_footer(lines, %{truncated?: true}, _result, _theme), do: lines

  defp maybe_append_file_limit_footer(lines, _truncation, result, theme) do
    if read_limit_truncated?(result) do
      lines
      |> Lines.join([""])
      |> Lines.join([read_limit_footer(theme)])
    else
      lines
    end
  end

  defp read_limit_truncated?(result),
    do: Map.get(result, :omitted_lines, 0) > 0 or Map.get(result, :omitted_bytes, 0) > 0

  defp read_limit_footer(theme) do
    [Widget.spaces(2), Theme.fg(theme, :muted, "… file truncated by read limit")]
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
end
