defmodule Exy.TUI.Widgets.Tools.FileMutation do
  @moduledoc false

  alias Exy.TUI
  alias Exy.TUI.{Theme, ToolWidget, Widget}

  @spec output_lines(term(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def output_lines(%{error: error}, width, theme), do: ToolWidget.error_lines(error, width, theme)

  def output_lines(%{change: %{diff: diff}}, width, theme) when is_binary(diff),
    do: output_diff(diff, width, theme)

  def output_lines(%{diff: diff}, width, theme) when is_binary(diff),
    do: output_diff(diff, width, theme)

  def output_lines(%{message: _message}, _width, _theme), do: []

  def output_lines(value, width, theme), do: ToolWidget.plain_lines(value, width, theme)

  defp output_diff(diff, width, theme) do
    TUI.diff(text: diff)
    |> Widget.render(max(width - 2, 1), theme)
    |> Enum.map(&[Widget.spaces(2), &1])
  end
end
