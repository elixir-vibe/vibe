defmodule Vibe.TUI.DiffBlock do
  @moduledoc "Renders diff-like TUI lines with semantic coloring."

  alias Vibe.TUI.{Syntax, Theme, Widget}

  @spec diff_lines([String.t()], atom() | String.t() | nil, pos_integer(), Theme.t()) :: [
          IO.chardata()
        ]
  def diff_lines(lines, language, width, theme) do
    Enum.flat_map(lines, fn line ->
      line
      |> highlight_diff_line(language, theme)
      |> output_line(width)
    end)
  end

  defp highlight_diff_line("+" <> rest, language, theme),
    do: [Theme.fg(theme, :success, "+"), highlight_diff_rest(rest, language, theme)]

  defp highlight_diff_line("-" <> rest, language, theme),
    do: [Theme.fg(theme, :error, "-"), highlight_diff_rest(rest, language, theme)]

  defp highlight_diff_line(line, _language, theme), do: Theme.fg(theme, :dim, line)

  defp highlight_diff_rest(rest, language, theme) do
    case split_diff_number_prefix(rest) do
      {prefix, source} ->
        [Theme.fg(theme, :dim, prefix), highlight_diff_source_line(source, language, theme)]

      :error ->
        Theme.fg(theme, :dim, rest)
    end
  end

  defp highlight_diff_source_line(line, language, theme) when language in [nil, ""],
    do: Theme.fg(theme, :tool_output, line)

  defp highlight_diff_source_line(line, language, _theme) when language in [:elixir, "elixir"],
    do: Syntax.highlight_elixir(line)

  defp highlight_diff_source_line(line, language, theme) do
    {:ok, highlighted} =
      Lumis.highlight(line, formatter: {:terminal, language: to_string(language)})

    highlighted
  rescue
    _error -> Theme.fg(theme, :tool_output, line)
  end

  defp split_diff_number_prefix(rest) do
    case Regex.run(~r/^(\s*\d+\s+\s)(.*)$/, rest, capture: :all_but_first) do
      [prefix, source] -> {prefix, source}
      _no_match -> :error
    end
  end

  defp output_line(line, width) do
    line
    |> Widget.wrap(max(width - 2, 1))
    |> Enum.map(&[Widget.spaces(2), &1])
  end
end
