defmodule Exy.TUI.Widgets.Tools.Read do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Lines, Theme, ToolWidget, Widget}
  alias Exy.TUI.Widgets.Tools.FileTool

  @impl true
  def render(tool, width, theme) do
    result = ToolWidget.output(tool)

    ToolWidget.block(tool, width, theme,
      name: :read,
      summary: FileTool.path_summary(tool, result),
      params?: false,
      output_lines: output_lines(result, max(width - 2, 1), theme)
    )
  end

  defp output_lines(%{error: error}, width, theme),
    do: ToolWidget.error_lines(error, width, theme)

  defp output_lines(%{content: content} = result, width, theme) when is_binary(content) do
    content_lines =
      content
      |> String.split("\n")
      |> Enum.flat_map(fn line ->
        Widget.wrap([Widget.spaces(2), highlight(line, Map.get(result, :language), theme)], width)
      end)

    footer = truncation_footer(result, theme)

    if footer == [] do
      content_lines
    else
      content_lines |> Lines.join([""]) |> Lines.join(footer)
    end
  end

  defp output_lines(value, width, theme), do: ToolWidget.plain_lines(value, width, theme)

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

  defp highlight(line, language, theme) when language in [nil, ""],
    do: Theme.fg(theme, :tool_output, line)

  defp highlight(line, language, theme) do
    {:ok, highlighted} = Lumis.highlight(line, formatter: {:terminal, language: language})
    highlighted
  rescue
    _error -> Theme.fg(theme, :tool_output, line)
  end
end
