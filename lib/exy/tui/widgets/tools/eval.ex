defmodule Exy.TUI.Widgets.Tools.Eval do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Duration, Markdown, ToolWidget}

  @impl true
  def render(tool, width, theme) do
    ToolWidget.block(tool, width, theme,
      name: :eval,
      action: timeout_summary(tool),
      summary: eval_summary(tool),
      summary_style: summary_style(tool),
      output_lines: structured_output_lines(tool, width, theme),
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

  defp structured_output_lines(%{output_parts: parts}, width, theme) when is_list(parts) do
    parts
    |> Enum.map(&normalize_part/1)
    |> Enum.reject(&(Map.get(&1, :output) in [nil, ""]))
    |> Enum.map(&part_lines(&1, width, theme))
    |> Enum.intersperse([""])
    |> List.flatten()
    |> case do
      [] -> nil
      lines -> lines
    end
  end

  defp structured_output_lines(tool, width, theme) do
    if markdown_output?(tool) do
      tool
      |> ToolWidget.output()
      |> Markdown.render(max(width - 2, 1), theme)
    end
  end

  defp normalize_part(%{format: _format, output: _output} = part), do: part

  defp normalize_part(%{"format" => format, "output" => output}) do
    %{format: normalize_format(format), output: output}
  end

  defp normalize_part(part), do: part

  defp normalize_format("inspect"), do: :inspect
  defp normalize_format("markdown"), do: :markdown
  defp normalize_format("text"), do: :text
  defp normalize_format(format), do: format

  defp part_lines(%{format: :inspect, output: output}, width, _theme) do
    output
    |> Exy.TUI.Syntax.highlight_elixir()
    |> String.split("\n")
    |> Enum.flat_map(fn line -> Exy.TUI.Widget.wrap([Exy.TUI.Widget.spaces(2), line], width) end)
  end

  defp part_lines(%{format: :markdown, output: output}, width, theme) do
    Markdown.render(output, max(width - 2, 1), theme)
  end

  defp part_lines(%{output: output}, width, theme) do
    output
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      Exy.TUI.Widget.wrap(
        [Exy.TUI.Widget.spaces(2), Exy.TUI.Theme.fg(theme, :tool_output, line)],
        width
      )
    end)
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

  defp format_timeout(timeout) when is_integer(timeout), do: Duration.milliseconds(timeout)
  defp format_timeout(timeout), do: to_string(timeout)

  defp code_from_args(%{code: code}), do: code
  defp code_from_args(%{"code" => code}), do: code
  defp code_from_args(args), do: args
end
