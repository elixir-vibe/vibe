defmodule Exy.TUI.Widgets.Tools.FileMutation do
  @moduledoc "TUI tool widget: shared file mutation display."
  alias Exy.TUI.{Syntax, TextTruncation, Theme, ToolWidget, Widget}

  @spec output_lines(term(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def output_lines(%{error: error}, width, theme), do: ToolWidget.error_lines(error, width, theme)

  def output_lines(%{change: change} = result, width, theme) when is_map(change),
    do: output_change(result, change, width, theme)

  def output_lines(%{diff: diff} = result, width, theme) when is_binary(diff),
    do: output_diff(diff, language(result), width, theme)

  def output_lines(%{message: _message}, _width, _theme), do: []

  def output_lines(value, width, theme), do: ToolWidget.plain_lines(value, width, theme)

  defp output_change(result, %{old: old, new: new} = change, width, theme)
       when is_binary(old) and is_binary(new) do
    if old == "" do
      output_created_file(new, language(result), width, theme)
    else
      output_diff(Map.get(change, :diff, ""), language(result), width, theme)
    end
  end

  defp output_change(result, %{diff: diff}, width, theme) when is_binary(diff),
    do: output_diff(diff, language(result), width, theme)

  defp output_change(_result, change, width, theme),
    do: ToolWidget.plain_lines(change, width, theme)

  defp output_created_file(content, language, width, theme) do
    content
    |> String.split("\n")
    |> TextTruncation.lines(limit: 8)
    |> render_source_lines(language, width, theme)
  end

  defp render_source_lines(
         %{lines: lines, omitted: omitted, truncated?: truncated?},
         language,
         width,
         theme
       ) do
    rendered =
      lines
      |> Enum.flat_map(fn line ->
        Widget.wrap([Widget.spaces(2), highlight(line, language, theme)], width)
      end)

    if truncated? do
      [TextTruncation.hint(omitted, theme, width) | Enum.reverse(rendered)] |> Enum.reverse()
    else
      rendered
    end
  end

  defp output_diff(diff, language, width, theme) do
    diff
    |> String.split("\n")
    |> Enum.map(&style_diff_line(&1, language, theme))
    |> Enum.flat_map(&Widget.wrap([Widget.spaces(2), &1], width))
  end

  defp style_diff_line("+" <> rest, language, theme),
    do: [Theme.fg(theme, :success, "+"), highlight_diff_rest(rest, language, theme)]

  defp style_diff_line("-" <> rest, language, theme),
    do: [Theme.fg(theme, :error, "-"), highlight_diff_rest(rest, language, theme)]

  defp style_diff_line(line, _language, theme), do: Theme.fg(theme, :dim, line)

  defp highlight_diff_rest(rest, language, theme) do
    case split_number_prefix(rest) do
      {prefix, source} -> [Theme.fg(theme, :dim, prefix), highlight(source, language, theme)]
      :error -> Theme.fg(theme, :dim, rest)
    end
  end

  defp split_number_prefix(rest) do
    case Regex.run(~r/^(\s*\d+\s+\s)(.*)$/, rest, capture: :all_but_first) do
      [prefix, source] -> {prefix, source}
      _no_match -> :error
    end
  end

  defp highlight(line, nil, theme), do: Theme.fg(theme, :tool_output, line)
  defp highlight(line, "", theme), do: Theme.fg(theme, :tool_output, line)
  defp highlight(line, "elixir", _theme), do: Syntax.highlight_elixir(line)

  defp highlight(line, language, theme) do
    {:ok, highlighted} = Lumis.highlight(line, formatter: {:terminal, language: language})
    highlighted
  rescue
    _error -> Theme.fg(theme, :tool_output, line)
  end

  defp language(%{language: language}), do: language
  defp language(%{path: path}) when is_binary(path), do: Exy.Files.language(path)
  defp language(%{change: %{path: path}}) when is_binary(path), do: Exy.Files.language(path)
  defp language(_result), do: nil
end
