defmodule Vibe.TUI.ToolWidget do
  @moduledoc """
  Behaviour and dispatcher for built-in tool widgets.
  """

  alias Vibe.Tool.Display
  alias Vibe.TUI

  alias Vibe.TUI.{
    Lines,
    SourceBlock,
    TextTruncation,
    Theme,
    ToolCard,
    ToolOutputBlock,
    ValueFormat,
    Widget
  }

  @type tool :: map()
  @callback render(tool(), pos_integer(), Theme.t()) :: [IO.chardata()]

  @spec render(tool(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render(%Display{} = display, width, theme), do: render_display(display, width, theme)

  def render(tool, width, theme) when is_map(tool) do
    tool |> Display.from_tool() |> render_display(width, theme)
  end

  def render_display(%Display{} = display, width, theme) do
    block(
      %{name: display.name, status: display.status, truncate?: display.truncate?},
      width,
      theme,
      name: display.name,
      summary: display.summary,
      meta: display.meta,
      summary_style: display.summary_style,
      output_lines: ToolOutputBlock.display_body_lines(display, max(width - 2, 1), theme),
      params?: false,
      truncation: :tail
    )
  end

  @spec block(tool(), pos_integer(), Theme.t(), keyword()) :: [IO.chardata()]
  def block(tool, width, theme, opts \\ []) do
    inner_width = max(width - 2, 1)

    sections =
      []
      |> maybe_append_command(inner_width, theme, opts)
      |> maybe_append_params(tool, inner_width, theme, opts)
      |> append_output(tool, inner_width, theme, opts)

    ToolCard.block(tool, width, theme, sections, opts)
  end

  @spec title(tool(), Theme.t(), keyword()) :: IO.chardata()
  def title(tool, theme, opts \\ []), do: ToolCard.title(tool, theme, opts)

  @spec title(tool(), pos_integer() | nil, Theme.t(), keyword()) :: IO.chardata()
  def title(tool, width, theme, opts), do: ToolCard.title(tool, width, theme, opts)

  def generic_lines(tool, width, theme),
    do: block(tool, width, theme, summary: compact_summary(tool))

  def compact_summary(tool) do
    cond do
      args = params(tool) -> summarize_value(args, 80)
      output = output(tool) -> summarize_value(output, 80)
      true -> nil
    end
  end

  def summarize_value(value, limit), do: ValueFormat.summarize(value, limit)
  def single_line(value), do: ValueFormat.single_line(value)

  def status_bg(text, status, theme), do: ToolCard.status_bg(text, status, theme)
  def status(tool), do: ToolCard.status(tool)
  def status_icon(status, theme), do: ToolCard.status_icon(status, theme)

  def params(tool), do: Map.get(tool, :args) || Map.get(tool, :params)

  def output(tool) do
    tool
    |> raw_output()
    |> unwrap_output()
  end

  def format_value(value), do: ValueFormat.format(value)
  def error_lines(error, width, theme), do: ValueFormat.error_lines(error, width, theme)

  def plain_lines(value, width, theme, opts \\ []),
    do: ValueFormat.plain_lines(value, width, theme, opts)

  def plain_line(line, width, theme, opts \\ []),
    do: ValueFormat.plain_line(line, width, theme, opts)

  def inspect_lines(value, width, theme), do: ValueFormat.inspect_lines(value, width, theme)
  def inspect_line(line, width, theme), do: ValueFormat.inspect_line(line, width, theme)
  def output_line(line, width), do: ValueFormat.output_line(line, width)

  def source_lines(lines, language, width, theme),
    do: SourceBlock.source_lines(lines, language, width, theme)

  defp raw_output(tool), do: Map.get(tool, :output) || Map.get(tool, :result)

  defp unwrap_output(%{output: output}), do: output
  defp unwrap_output(output), do: output

  defp maybe_append_command(lines, width, theme, opts) do
    case Keyword.get(opts, :command) do
      nil -> lines
      command -> append_section(lines, :command, command, width, theme, %{})
    end
  end

  defp maybe_append_params(lines, tool, width, theme, opts) do
    if Keyword.get(opts, :params?, true) do
      append_section(lines, :params, params(tool), width, theme, tool)
    else
      lines
    end
  end

  defp append_output(lines, tool, width, theme, opts) do
    case Keyword.get(opts, :output_lines) do
      nil ->
        append_section(lines, :output, output(tool), width, theme, tool, opts)

      output_lines ->
        lines
        |> Lines.join([""])
        |> Lines.join(output_lines)
    end
  end

  defp append_section(lines, label, value, width, theme, tool),
    do: append_section(lines, label, value, width, theme, tool, [])

  defp append_section(lines, _label, nil, _width, _theme, _tool, _opts), do: lines

  defp append_section(
         lines,
         :output,
         value,
         width,
         theme,
         %{output_format: :inspect} = tool,
         opts
       )
       when is_binary(value) do
    append_default_section(lines, :output, value, width, theme, tool, opts)
  end

  defp append_section(lines, :output, value, width, theme, tool, opts) when is_binary(value) do
    value_lines = binary_output_lines(value, width, theme, tool, opts)
    lines |> Lines.join(section_label_lines(:output, width, theme)) |> Lines.join(value_lines)
  end

  defp append_section(lines, label, value, width, theme, tool, opts),
    do: append_default_section(lines, label, value, width, theme, tool, opts)

  defp append_default_section(lines, label, value, width, theme, tool, opts) do
    label_lines = section_label_lines(label, width, theme)

    value_lines =
      value_lines(label, value, width, theme, tool)
      |> maybe_truncate(label, tool, width, theme, opts)

    lines |> Lines.join(label_lines) |> Lines.join(value_lines)
  end

  defp section_label_lines(:output, _width, _theme), do: [""]

  defp section_label_lines(label, width, theme) do
    Widget.render(TUI.text([Theme.fg(theme, :muted, [to_string(label), ":"])]), width, theme)
  end

  defp binary_output_lines(value, width, theme, tool, opts) do
    mode = Keyword.get(opts, :truncation, :head)

    truncation =
      value
      |> String.split("\n")
      |> TextTruncation.lines(enabled?: Map.get(tool, :truncate?, true), limit: 8, mode: mode)

    lines =
      Enum.flat_map(truncation.lines, fn line ->
        Widget.wrap([Widget.spaces(2), Theme.fg(theme, :tool_output, line)], width)
      end)

    truncated_lines(%{truncation | lines: lines}, mode, theme, width)
  end

  defp value_lines(:output, %{error: error}, width, theme, _tool),
    do: error_lines(error, width, theme)

  defp value_lines(:output, value, width, theme, %{output_format: :inspect}),
    do: inspect_lines(value, width, theme)

  defp value_lines(:output, value, width, theme, _tool), do: plain_lines(value, width, theme)

  defp value_lines(_label, value, width, theme, _tool) do
    Widget.render(
      TUI.padding([TUI.text(format_value(value), fg: :tool_output)], x: 2),
      width,
      theme
    )
  end

  def format_error(error), do: ValueFormat.format_error(error)
  defp maybe_truncate(lines, :params, _tool, _width, _theme, _opts), do: lines

  defp maybe_truncate(lines, _label, tool, width, theme, opts) do
    mode = Keyword.get(opts, :truncation, :head)

    truncation =
      TextTruncation.lines(lines,
        enabled?: Map.get(tool, :truncate?, true),
        limit: 8,
        mode: mode
      )

    truncated_lines(truncation, mode, theme, width)
  end

  defp truncated_lines(%{truncated?: false, lines: lines}, _mode, _theme, _width), do: lines

  defp truncated_lines(%{lines: lines, omitted: omitted}, :tail, theme, width) do
    [TextTruncation.hint(omitted, theme, width), ""]
    |> Lines.join(lines)
  end

  defp truncated_lines(%{lines: lines, omitted: omitted}, _mode, theme, width) do
    lines
    |> Lines.join([""])
    |> Lines.join([TextTruncation.hint(omitted, theme, width)])
  end
end
