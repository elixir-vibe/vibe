defmodule Exy.TUI.Widgets.Tools.LSP do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{DSL, Theme, ToolWidget, Widget}

  @impl true
  def render(tool, width, theme) do
    output = Map.get(tool, :output) || Map.get(tool, :result)

    title =
      ToolWidget.title(tool, theme,
        name: :elixir_lsp,
        action: action(tool),
        summary: collapsed_summary(output)
      )

    if Map.get(tool, :expanded?, false) do
      [title | details(output, width, theme)]
    else
      [title]
    end
  end

  defp details(nil, _width, _theme), do: []

  defp details([], width, theme),
    do: Widget.render(DSL.text("0 diagnostics", fg: :success), width, theme)

  defp details(diagnostics, width, theme) when is_list(diagnostics) do
    rows = diagnostics |> Enum.take(8) |> Enum.map(&diagnostic_row(&1, theme))
    more = max(length(diagnostics) - length(rows), 0)

    rows =
      if more > 0, do: rows ++ [Theme.fg(theme, :muted, "+#{more} more diagnostics")], else: rows

    Widget.render(
      DSL.padding(Enum.map(rows, &DSL.text(&1, fg: :tool_output)), x: 2),
      width,
      theme
    )
  end

  defp details(value, width, theme),
    do: Widget.render(DSL.text(format_output(value), fg: :tool_output), width, theme)

  defp action(tool) do
    case Map.get(tool, :args) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _ -> nil
    end
  end

  defp collapsed_summary([]), do: "0 diagnostics"
  defp collapsed_summary(list) when is_list(list), do: "#{length(list)} diagnostics"
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)

  defp diagnostic_row(%{severity: severity, message: message} = diagnostic, theme) do
    location = diagnostic |> Map.get(:range) |> format_range()
    [severity_icon(severity, theme), " ", location, to_string(message)]
  end

  defp diagnostic_row(%{"severity" => severity, "message" => message} = diagnostic, theme) do
    location = diagnostic |> Map.get("range") |> format_range()
    [severity_icon(severity, theme), " ", location, to_string(message)]
  end

  defp diagnostic_row(diagnostic, _theme), do: ToolWidget.summarize_value(diagnostic, 100)

  defp severity_icon(severity, theme) when severity in [:error, "error", 1],
    do: Theme.symbol(theme, :error_icon)

  defp severity_icon(_severity, theme), do: Theme.symbol(theme, :warning_icon)

  defp format_range(nil), do: ""
  defp format_range(%{start: %{line: line}}), do: "#{line + 1}: "
  defp format_range(%{"start" => %{"line" => line}}), do: "#{line + 1}: "
  defp format_range(_range), do: ""

  defp format_output(nil), do: ""
  defp format_output(value) when is_binary(value), do: value
  defp format_output(value), do: inspect(value, pretty: true, limit: 20)
end
