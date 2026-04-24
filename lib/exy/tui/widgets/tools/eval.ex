defmodule Exy.TUI.Widgets.Tools.Eval do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{DSL, Theme, ToolWidget, Widget}

  @impl true
  def render(tool, width, theme) do
    title = ToolWidget.title(tool, theme, name: :elixir_eval, summary: eval_summary(tool))

    if expanded?(tool) do
      [title | detail_lines(tool, width, theme)]
    else
      [title]
    end
  end

  defp eval_summary(tool) do
    cond do
      code = Map.get(tool, :code) -> ToolWidget.summarize_value(code, 72)
      args = Map.get(tool, :args) -> args |> code_from_args() |> ToolWidget.summarize_value(72)
      true -> ToolWidget.compact_summary(tool)
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
      Widget.render(DSL.text([Theme.fg(theme, :muted, [to_string(label), ":"])]), width, theme) ++
      Widget.render(
        DSL.padding([DSL.text(format_value(value), fg: :tool_output)], x: 2),
        width,
        theme
      )
  end

  defp code_from_args(%{code: code}), do: code
  defp code_from_args(%{"code" => code}), do: code
  defp code_from_args(args), do: args

  defp expanded?(tool), do: Map.get(tool, :expanded?, false)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value, pretty: true, limit: 20)
end
