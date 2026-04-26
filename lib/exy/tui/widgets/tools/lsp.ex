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
      summary: collapsed_summary(output)
    )
  end

  defp action(tool) do
    case Map.get(tool, :args) do
      %{action: action} -> to_string(action)
      _ -> nil
    end
  end

  defp collapsed_summary([]), do: "0 diagnostics"
  defp collapsed_summary(list) when is_list(list), do: "#{length(list)} diagnostics"
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)
end
