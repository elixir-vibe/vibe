defmodule Exy.TUI.Widgets.Tools.LSP do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.ToolWidget

  @impl true
  def render(tool, width, theme) do
    output = Map.get(tool, :output) || Map.get(tool, :result)

    ToolWidget.block(tool, width, theme,
      name: :lsp,
      action: action(tool),
      summary: lsp_summary(tool, output),
      params?: false
    )
  end

  defp action(tool) do
    case args(tool) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _ -> nil
    end
  end

  defp lsp_summary(tool, output) do
    case {args(tool), output} do
      {%{file: file}, _output} when is_binary(file) -> file
      {%{"file" => file}, _output} when is_binary(file) -> file
      {%{query: query}, _output} when is_binary(query) -> query
      {%{"query" => query}, _output} when is_binary(query) -> query
      {_args, output} -> collapsed_summary(output)
    end
  end

  defp args(tool), do: Map.get(tool, :args) || %{}

  defp collapsed_summary([]), do: "0 diagnostics"
  defp collapsed_summary(list) when is_list(list), do: "#{length(list)} diagnostics"
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)
end
