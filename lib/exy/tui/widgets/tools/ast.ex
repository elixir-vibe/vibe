defmodule Exy.TUI.Widgets.Tools.AST do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.ToolWidget

  @impl true
  def render(tool, width, theme) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    ToolWidget.block(tool, width, theme,
      name: :ast,
      action: action(tool),
      summary: ast_summary(tool, result),
      params?: false
    )
  end

  defp action(tool) do
    case args(tool) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _args -> nil
    end
  end

  defp ast_summary(tool, result) do
    case {args(tool), result} do
      {%{path: path}, _result} when is_binary(path) -> path
      {%{"path" => path}, _result} when is_binary(path) -> path
      {%{file: file}, _result} when is_binary(file) -> file
      {%{"file" => file}, _result} when is_binary(file) -> file
      {%{pattern: pattern}, _result} when is_binary(pattern) -> pattern
      {%{"pattern" => pattern}, _result} when is_binary(pattern) -> pattern
      {_args, result} -> collapsed_summary(result)
    end
  end

  defp args(tool), do: Map.get(tool, :args) || %{}

  defp collapsed_summary(matches) when is_list(matches), do: "#{length(matches)} matches"
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)
end
