defmodule Exy.TUI.Widgets.Tools.AST do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{DSL, Lines, Theme, ToolWidget, Widget}

  @impl true
  def render(tool, width, theme) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    title =
      ToolWidget.title(tool, theme,
        name: :elixir_ast,
        action: action(tool),
        summary: collapsed_summary(result)
      )

    if Map.get(tool, :expanded?, false) do
      [title | details(result, width, theme)]
    else
      [title]
    end
  end

  defp details(nil, _width, _theme), do: []

  defp details(matches, width, theme) when is_list(matches) do
    rows = Enum.take(matches, 8) |> Enum.map(&match_row/1)
    more = max(length(matches) - length(rows), 0)

    body = Lines.append_if(rows, more > 0, Theme.fg(theme, :muted, "+#{more} more matches"))

    Widget.render(
      DSL.padding(Enum.map(body, &DSL.text(&1, fg: :tool_output)), x: 2),
      width,
      theme
    )
  end

  defp details(value, width, theme),
    do: Widget.render(DSL.text(summary(value), fg: :tool_output), width, theme)

  defp action(tool) do
    case Map.get(tool, :args) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _ -> nil
    end
  end

  defp collapsed_summary(matches) when is_list(matches), do: "#{length(matches)} matches"
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)

  defp match_row(%{file: file, line: line}), do: [to_string(file), ":", to_string(line)]
  defp match_row(%{"file" => file, "line" => line}), do: [to_string(file), ":", to_string(line)]
  defp match_row(match), do: ToolWidget.summarize_value(match, 100)

  defp summary(nil), do: ""
  defp summary(value) when is_binary(value), do: value
  defp summary(value), do: inspect(value, pretty: true, limit: 20)
end
