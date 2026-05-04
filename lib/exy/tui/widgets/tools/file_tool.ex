defmodule Exy.TUI.Widgets.Tools.FileTool do
  @moduledoc "TUI tool widget: shared file path summary."
  alias Exy.TUI.ToolWidget

  @spec path_summary(map(), term()) :: String.t() | nil
  def path_summary(tool, result),
    do: path_from_args(tool) || path_from_result(result) || ToolWidget.compact_summary(tool)

  defp path_from_args(%{args: %{path: path}}), do: path
  defp path_from_args(_tool), do: nil

  defp path_from_result(%{path: path}), do: path
  defp path_from_result(_result), do: nil
end
