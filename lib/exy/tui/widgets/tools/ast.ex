defmodule Exy.TUI.Widgets.Tools.AST do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.ToolWidget

  @impl true
  def render(tool, width, theme) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    ToolWidget.block(tool, width, theme,
      name: :elixir_ast,
      action: action(tool),
      summary: collapsed_summary(result)
    )
  end

  defp action(tool) do
    case Map.get(tool, :args) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _ -> nil
    end
  end

  defp collapsed_summary(matches) when is_list(matches), do: "#{length(matches)} matches"
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)
end
