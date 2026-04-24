defmodule Exy.TUI.Widgets.Tools.AST do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{DSL, Theme, ToolWidget, Widget}

  @impl true
  def render(tool, width, theme) do
    title =
      theme
      |> Theme.fg(:tool_title, [
        Theme.symbol(theme, :tool_icon),
        " elixir_ast  ",
        action(tool),
        "  ",
        status(tool)
      ])
      |> ToolWidget.status_bg(Map.get(tool, :status), theme)

    if Map.get(tool, :expanded?, false) do
      [title | details(tool, width, theme)]
    else
      [title]
    end
  end

  defp details(tool, width, theme) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    Widget.render(DSL.text(summary(result), fg: :tool_output), width, theme)
  end

  defp action(tool) do
    case Map.get(tool, :args) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _ -> ""
    end
  end

  defp summary(nil), do: ""

  defp summary(list) when is_list(list),
    do: "matches: #{length(list)}\n" <> inspect(list, pretty: true, limit: 10)

  defp summary(value) when is_binary(value), do: value
  defp summary(value), do: inspect(value, pretty: true, limit: 20)

  defp status(tool), do: tool |> Map.get(:status, :running) |> to_string()
end
