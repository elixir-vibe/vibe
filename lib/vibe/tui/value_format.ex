defmodule Vibe.TUI.ValueFormat do
  @moduledoc "Formats generic values for TUI tool output."

  alias Vibe.TUI.{Syntax}
  alias Vibe.Terminal.{Theme}
  alias Vibe.TUI.Widget

  @spec summarize(term(), non_neg_integer() | :infinity) :: String.t()
  def summarize(value, :infinity) when is_binary(value), do: single_line(value)
  def summarize(value, :infinity), do: value |> inspect(limit: :infinity) |> single_line()

  def summarize(value, limit) when is_binary(value),
    do: value |> single_line() |> String.slice(0, limit)

  def summarize(value, limit),
    do: value |> inspect(limit: 8) |> single_line() |> String.slice(0, limit)

  @spec single_line(String.t()) :: String.t()
  def single_line(value) when is_binary(value), do: String.replace(value, "\n", " ")

  @spec format(term()) :: String.t()
  def format(value) when is_binary(value), do: value
  def format(value), do: inspect(value, pretty: true, limit: 20)

  @spec error_lines(term(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def error_lines(error, width, theme) do
    error
    |> format_error()
    |> plain_lines(width, theme, fg: :error)
  end

  @spec plain_lines(term(), pos_integer(), Theme.t(), keyword()) :: [IO.chardata()]
  def plain_lines(value, width, theme, opts \\ []) do
    fg = Keyword.get(opts, :fg, :tool_output)

    value
    |> format()
    |> String.split("\n")
    |> Enum.flat_map(&plain_line(&1, width, theme, fg: fg))
  end

  @spec plain_line(String.t(), pos_integer(), Theme.t(), keyword()) :: [IO.chardata()]
  def plain_line(line, width, theme, opts \\ []) do
    fg = Keyword.get(opts, :fg, :tool_output)
    line |> then(&Theme.fg(theme, fg, &1)) |> output_line(width)
  end

  @spec inspect_lines(term(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def inspect_lines(value, width, theme) do
    value
    |> format()
    |> String.split("\n")
    |> Enum.flat_map(&inspect_line(&1, width, theme))
  end

  @spec inspect_line(String.t(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def inspect_line(line, width, _theme) do
    line
    |> Syntax.highlight_elixir()
    |> output_line(width)
  end

  @spec output_line(IO.chardata(), pos_integer()) :: [IO.chardata()]
  def output_line(line, width), do: wrap_output_line(line, width)

  @spec format_error(term()) :: String.t()
  def format_error(error) when is_binary(error), do: error
  def format_error(error), do: inspect(error, pretty: true, limit: 20)

  @spec wrap_output_line(IO.chardata(), pos_integer()) :: [IO.chardata()]
  def wrap_output_line(line, width) do
    line
    |> Widget.wrap(max(width - 2, 1))
    |> Enum.map(&[Widget.spaces(2), &1])
  end
end
