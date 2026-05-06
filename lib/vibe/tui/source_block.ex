defmodule Vibe.TUI.SourceBlock do
  @moduledoc "Renders source-like TUI lines with block-level syntax highlighting."

  alias Vibe.TUI.{Syntax, Theme, Widget}

  @spec source_lines([String.t()], atom() | String.t() | nil, pos_integer(), Theme.t()) :: [
          IO.chardata()
        ]
  def source_lines(lines, language, width, theme) when language in [nil, ""] do
    Enum.flat_map(lines, fn line ->
      line
      |> then(&Theme.fg(theme, :tool_output, &1))
      |> output_line(width)
    end)
  end

  def source_lines(lines, language, width, theme) do
    lines
    |> Enum.join("\n")
    |> highlight_source(language)
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.flat_map(&output_line(&1, width))
  rescue
    _error -> source_lines(lines, nil, width, theme)
  end

  defp highlight_source(source, language) when language in [:elixir, "elixir"],
    do: Syntax.highlight_elixir(source)

  defp highlight_source(source, language) do
    {:ok, highlighted} =
      Lumis.highlight(source, formatter: {:terminal, language: to_string(language)})

    highlighted
  end

  defp output_line(line, width) do
    line
    |> Widget.wrap(max(width - 2, 1))
    |> Enum.map(&[Widget.spaces(2), &1])
  end
end
