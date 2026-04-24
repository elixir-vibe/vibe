defmodule Exy.TUI.Widgets.Tools.Eval do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Node, Theme, ToolWidget}

  @impl true
  def render(tool, width, theme) do
    title =
      theme
      |> Theme.fg(:tool_title, ["◆ elixir_eval  ", status(tool)])
      |> ToolWidget.status_bg(Map.get(tool, :status), theme)

    lines = [title]

    if expanded?(tool) do
      lines ++ detail_lines(tool, width, theme)
    else
      lines
    end
  end

  defp detail_lines(tool, width, theme) do
    []
    |> append_section(:code, Map.get(tool, :args) || Map.get(tool, :code), width, theme)
    |> append_section(:output, Map.get(tool, :output) || Map.get(tool, :result), width, theme)
  end

  defp append_section(lines, _label, nil, _width, _theme), do: lines

  defp append_section(lines, label, value, width, theme) do
    lines ++
      Node.render(Node.text([to_string(label), ":"], fg: :muted), width, theme) ++
      Node.render(Node.text(format_value(value), fg: :tool_output), width, theme)
  end

  defp expanded?(tool), do: Map.get(tool, :expanded?, false)
  defp status(tool), do: tool |> Map.get(:status, :running) |> to_string()
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value, pretty: true, limit: 20)
end
