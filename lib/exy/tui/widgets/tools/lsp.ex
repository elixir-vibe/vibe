defmodule Exy.TUI.Widgets.Tools.LSP do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{DSL, Theme, ToolWidget, Widget}

  @impl true
  def render(tool, width, theme) do
    title =
      theme
      |> Theme.fg(:tool_title, [
        Theme.symbol(theme, :tool_icon),
        " elixir_lsp  ",
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
    output = Map.get(tool, :output) || Map.get(tool, :result)
    Widget.render(DSL.text(format_output(output), fg: :tool_output), width, theme)
  end

  defp action(tool) do
    case Map.get(tool, :args) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _ -> ""
    end
  end

  defp format_output(nil), do: ""
  defp format_output([]), do: "0 diagnostics"
  defp format_output(value) when is_binary(value), do: value
  defp format_output(value), do: inspect(value, pretty: true, limit: 20)

  defp status(tool), do: tool |> Map.get(:status, :running) |> to_string()
end
