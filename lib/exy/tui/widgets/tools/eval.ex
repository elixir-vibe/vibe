defmodule Exy.TUI.Widgets.Tools.Eval do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Markdown, ToolWidget}

  @impl true
  def render(tool, width, theme) do
    ToolWidget.block(tool, width, theme,
      name: :eval,
      action: timeout_summary(tool),
      summary: eval_summary(tool),
      summary_style: summary_style(tool),
      output_lines: markdown_output_lines(tool, width, theme),
      params?: false
    )
  end

  defp eval_summary(tool) do
    cond do
      code = Map.get(tool, :code) ->
        ToolWidget.summarize_value(code, :infinity)

      args = Map.get(tool, :args) ->
        args |> code_from_args() |> ToolWidget.summarize_value(:infinity)

      true ->
        ToolWidget.compact_summary(tool)
    end
  end

  defp summary_style(tool) do
    tool
    |> Map.get(:args)
    |> code_from_args()
    |> command_expression?()
    |> case do
      true -> :elixir_dim
      false -> nil
    end
  end

  defp command_expression?(code) when is_binary(code) do
    code = String.trim_leading(code)
    String.starts_with?(code, ["Cmd.run(", "Cmd.start(", "System.cmd("])
  end

  defp command_expression?(_code), do: false

  defp markdown_output_lines(tool, width, theme) do
    if markdown_output?(tool) do
      tool
      |> ToolWidget.output()
      |> Markdown.render(max(width - 2, 1), theme)
    end
  end

  defp markdown_output?(%{output_format: :markdown}), do: true
  defp markdown_output?(_tool), do: false

  defp timeout_summary(tool) do
    case Map.get(tool, :args) || %{} do
      %{timeout: timeout} -> format_timeout(timeout)
      %{"timeout" => timeout} -> format_timeout(timeout)
      _args -> nil
    end
  end

  defp format_timeout(timeout) when is_integer(timeout) and rem(timeout, 1000) == 0,
    do: "#{div(timeout, 1000)}s"

  defp format_timeout(timeout) when is_integer(timeout), do: "#{Float.round(timeout / 1000, 1)}s"
  defp format_timeout(timeout), do: to_string(timeout)

  defp code_from_args(%{code: code}), do: code
  defp code_from_args(%{"code" => code}), do: code
  defp code_from_args(args), do: args
end
