defmodule Exy.TUI.Widgets.Tools.FileMutation do
  @moduledoc false

  alias Exy.TUI.{DSL, Lines, Theme, ToolWidget, Widget}

  @spec output_lines(term(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def output_lines(%{error: error}, width, theme) do
    error
    |> format_error()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      Widget.wrap([Widget.spaces(2), Theme.fg(theme, :error, line)], width)
    end)
  end

  def output_lines(%{message: message, diff: diff}, width, theme) when is_binary(diff) do
    message_lines = Widget.wrap([Widget.spaces(2), Theme.fg(theme, :muted, message)], width)

    diff_lines =
      DSL.diff(text: diff)
      |> Widget.render(max(width - 2, 1), theme)
      |> Enum.map(&[Widget.spaces(2), &1])

    message_lines |> Lines.join([""]) |> Lines.join(diff_lines)
  end

  def output_lines(value, width, theme) do
    value
    |> ToolWidget.format_value()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      Widget.wrap([Widget.spaces(2), Theme.fg(theme, :tool_output, line)], width)
    end)
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error, pretty: true, limit: 20)
end
