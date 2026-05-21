defmodule Vibe.TUI.Widgets.Tools.Eval do
  @moduledoc "TUI tool widget: eval output with ANSI."
  @behaviour Vibe.TUI.ToolWidget

  alias Vibe.TUI.{Duration, Lines, Markdown, Syntax, TextTruncation, ToolWidget}

  @impl true
  def render(tool, width, theme) do
    ToolWidget.block(tool, width, theme,
      name: :eval,
      summary: eval_summary(tool),
      meta: [timeout_summary(tool)],
      summary_style: summary_style(tool),
      output_lines: structured_output_lines(tool, max(width - 2, 1), theme),
      params?: false,
      truncation: :tail
    )
  end

  defp eval_summary(tool) do
    cond do
      expanded?(tool) ->
        nil

      code = Map.get(tool, :code) ->
        ToolWidget.summarize_value(code, :infinity)

      args = Map.get(tool, :args) ->
        args |> code_from_args() |> ToolWidget.summarize_value(:infinity)

      true ->
        ToolWidget.compact_summary(tool)
    end
  end

  defp summary_style(tool) do
    cond do
      expanded?(tool) -> nil
      is_binary(code_from_tool(tool)) -> :elixir_dim
      true -> nil
    end
  end

  defp structured_output_lines(%{output_parts: parts} = tool, width, theme) when is_list(parts) do
    output_lines =
      parts
      |> Enum.map(&normalize_part/1)
      |> Enum.reject(&(Map.get(&1, :output) in [nil, ""]))
      |> Enum.map(&part_lines(&1, tool, width, theme))
      |> Enum.intersperse([""])
      |> Enum.flat_map(& &1)

    tool
    |> expanded_code_lines(width, theme)
    |> join_expanded_output(output_lines)
    |> case do
      [] -> nil
      lines -> lines
    end
  end

  defp structured_output_lines(tool, width, theme) do
    output_lines =
      cond do
        markdown_output?(tool) ->
          tool
          |> ToolWidget.output()
          |> Markdown.render(max(width - 2, 1), theme)

        expanded?(tool) ->
          case error_output(ToolWidget.output(tool)) do
            nil ->
              if is_nil(ToolWidget.output(tool)) do
                []
              else
                part_lines(
                  %{output: ToolWidget.output(tool), format: Map.get(tool, :output_format)},
                  tool,
                  width,
                  theme
                )
              end

            error ->
              ToolWidget.error_lines(error, width, theme)
          end

        true ->
          []
      end

    tool
    |> expanded_code_lines(width, theme)
    |> join_expanded_output(output_lines)
    |> case do
      [] -> nil
      lines -> lines
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

  defp part_lines(%{format: :inspect, output: output}, tool, width, theme) do
    output
    |> output_line_window(tool)
    |> render_output_window(:inspect, width, theme)
  end

  defp part_lines(%{format: :markdown, output: output}, _tool, width, theme) do
    Markdown.render(output, max(width - 2, 1), theme)
  end

  defp part_lines(%{output: output}, tool, width, theme) do
    output
    |> output_line_window(tool)
    |> render_output_window(:text, width, theme)
  end

  defp output_line_window(output, tool) do
    output
    |> ToolWidget.format_value()
    |> String.split("\n")
    |> TextTruncation.lines(enabled?: Map.get(tool, :truncate?, true), limit: 8, mode: :tail)
  end

  defp render_output_window(%{lines: lines, truncated?: false}, format, width, theme),
    do: Enum.flat_map(lines, &render_output_line(&1, format, width, theme))

  defp render_output_window(%{lines: lines, omitted: omitted}, format, width, theme) do
    [TextTruncation.hint(omitted, theme, width), ""]
    |> Lines.join(Enum.flat_map(lines, &render_output_line(&1, format, width, theme)))
  end

  defp render_output_line(line, :inspect, width, theme),
    do: ToolWidget.inspect_line(line, width, theme)

  defp render_output_line(line, _format, width, theme),
    do: ToolWidget.plain_line(line, width, theme)

  defp expanded_code_lines(tool, width, _theme) do
    if expanded?(tool) do
      tool
      |> code_from_tool()
      |> case do
        code when is_binary(code) and code != "" -> code_lines(code, width)
        _code -> []
      end
    else
      []
    end
  end

  defp join_expanded_output([], output_lines), do: output_lines
  defp join_expanded_output(code_lines, []), do: code_lines

  defp join_expanded_output(code_lines, output_lines),
    do: code_lines |> Lines.join([""]) |> Lines.join(output_lines)

  defp code_lines(code, width) do
    code
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      line
      |> Syntax.highlight_elixir()
      |> ToolWidget.output_line(width)
    end)
  end

  defp error_output(%{error: error}), do: error
  defp error_output(_output), do: nil

  defp expanded?(tool), do: Map.get(tool, :expanded?, false) or Map.get(tool, :truncate?) == false

  defp code_from_tool(tool) do
    cond do
      code = Map.get(tool, :code) -> code
      args = Map.get(tool, :args) -> code_from_args(args)
      true -> nil
    end
  end

  defp markdown_output?(%{output_format: :markdown}), do: true
  defp markdown_output?(_tool), do: false

  defp timeout_summary(tool) do
    case Vibe.Tool.Presentation.Util.timeout_arg(tool) do
      nil -> nil
      timeout -> format_timeout(timeout)
    end
  end

  defp format_timeout(timeout) when is_integer(timeout), do: Duration.milliseconds(timeout)
  defp format_timeout(timeout), do: to_string(timeout)

  defp code_from_args(%{code: code}), do: code
  defp code_from_args(%{"code" => code}), do: code
  defp code_from_args(args), do: args
end
