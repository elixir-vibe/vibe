defmodule Exy.TUI.Widgets.Tools.FileMutation do
  @moduledoc false

  alias Exy.TUI
  alias Exy.TUI.{Lines, Theme, ToolWidget, Widget}

  @spec output_lines(term(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def output_lines(%{error: error}, width, theme), do: ToolWidget.error_lines(error, width, theme)

  def output_lines(%{message: message, change: %{diff: diff}}, width, theme)
      when is_binary(diff) do
    output_diff(message, diff, width, theme)
  end

  def output_lines(%{message: message, diff: diff}, width, theme) when is_binary(diff) do
    output_diff(message, diff, width, theme)
  end

  def output_lines(value, width, theme), do: ToolWidget.plain_lines(value, width, theme)

  defp output_diff(message, diff, width, theme) do
    message_lines = Widget.wrap([Widget.spaces(2), Theme.fg(theme, :muted, message)], width)

    diff_lines =
      TUI.diff(text: diff)
      |> Widget.render(max(width - 2, 1), theme)
      |> Enum.map(&[Widget.spaces(2), &1])

    message_lines |> Lines.join([""]) |> Lines.join(diff_lines)
  end
end
