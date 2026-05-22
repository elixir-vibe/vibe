defmodule Vibe.TUI.DiffBlock do
  @moduledoc "Renders diff-like TUI lines with semantic coloring and intra-line word diff."

  alias Vibe.TUI.{Syntax}
  alias Vibe.Terminal.{Theme}
  alias Vibe.TUI.Widget

  @spec diff_lines([String.t()], atom() | String.t() | nil, pos_integer(), Theme.t()) :: [
          IO.chardata()
        ]
  def diff_lines(lines, language, width, theme) do
    lines
    |> apply_intra_line_diffs(theme)
    |> Enum.flat_map(fn
      {:rendered, iodata} -> output_line(iodata, width)
      line -> line |> highlight_diff_line(language, theme) |> output_line(width)
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

  defp apply_intra_line_diffs(lines, theme) do
    lines
    |> Enum.chunk_while(
      nil,
      fn
        "-" <> _ = line, nil -> {:cont, line}
        "+" <> _ = line, "-" <> _ = removed -> {:cont, {:pair, removed, line}, nil}
        line, nil -> {:cont, line, nil}
        line, held -> {:cont, held, line}
      end,
      fn
        nil -> {:cont, nil}
        held -> {:cont, held, nil}
      end
    )
    |> Enum.flat_map(fn
      {:pair, removed, added} -> render_intra_pair(removed, added, theme)
      line -> [line]
    end)
  end

  defp render_intra_pair("-" <> removed_rest, "+" <> added_rest, theme) do
    {removed_prefix, removed_source} = split_prefix(removed_rest)
    {added_prefix, added_source} = split_prefix(added_rest)

    removed_words = String.split(removed_source, ~r/\b/, include_captures: true)
    added_words = String.split(added_source, ~r/\b/, include_captures: true)

    {removed_parts, added_parts} = word_diff(removed_words, added_words)

    removed_line = [
      Theme.fg(theme, :error, "-"),
      Theme.fg(theme, :dim, removed_prefix),
      render_word_parts(removed_parts, theme, :error)
    ]

    added_line = [
      Theme.fg(theme, :success, "+"),
      Theme.fg(theme, :dim, added_prefix),
      render_word_parts(added_parts, theme, :success)
    ]

    [{:rendered, removed_line}, {:rendered, added_line}]
  end

  defp split_prefix(rest) do
    case Regex.run(~r/^(\s*\d+\s+\s)(.*)$/, rest, capture: :all_but_first) do
      [prefix, source] -> {prefix, source}
      _no_match -> {"", rest}
    end
  end

  defp render_word_parts(parts, theme, color) do
    Enum.map(parts, fn
      {:same, text} -> Theme.fg(theme, :dim, text)
      {:changed, text} -> [IO.ANSI.inverse(), Theme.fg(theme, color, text), IO.ANSI.inverse_off()]
    end)
  end

  defp word_diff(old_words, new_words) do
    old_set = MapSet.new(old_words)
    new_set = MapSet.new(new_words)

    old_parts =
      Enum.map(old_words, fn w ->
        if MapSet.member?(new_set, w), do: {:same, w}, else: {:changed, w}
      end)

    new_parts =
      Enum.map(new_words, fn w ->
        if MapSet.member?(old_set, w), do: {:same, w}, else: {:changed, w}
      end)

    {old_parts, new_parts}
  end
end
