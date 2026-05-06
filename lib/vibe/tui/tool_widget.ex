defmodule Vibe.TUI.ToolWidget do
  @moduledoc """
  Behaviour and dispatcher for built-in tool widgets.
  """

  alias Vibe.Model.Content
  alias Vibe.Tool.Display
  alias Vibe.TUI

  alias Vibe.TUI.{
    DiffBlock,
    Lines,
    Markdown,
    SourceBlock,
    Syntax,
    TextTruncation,
    Theme,
    Widget,
    Width
  }

  alias Vibe.TUI.Widgets.Image

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
      output_lines: display_body_lines(display, max(width - 2, 1), theme),
      params?: false,
      truncation: :tail
    )
  end

  @spec block(tool(), pos_integer(), Theme.t(), keyword()) :: [IO.chardata()]
  def block(tool, width, theme, opts \\ []) do
    inner_width = max(width - 2, 1)
    title = title(tool, inner_width, theme, opts)

    sections =
      []
      |> maybe_append_command(inner_width, theme, opts)
      |> maybe_append_params(tool, inner_width, theme, opts)
      |> append_output(tool, inner_width, theme, opts)

    [title | sections]
    |> Enum.map(&Widget.inset_line(&1, width))
  end

  @spec title(tool(), Theme.t(), keyword()) :: IO.chardata()
  def title(tool, theme, opts \\ []), do: title(tool, nil, theme, opts)

  @spec title(tool(), pos_integer() | nil, Theme.t(), keyword()) :: IO.chardata()
  def title(tool, width, theme, opts) do
    name = opts[:name] || tool_name(tool) || "tool"
    action = opts[:action]
    summary = opts[:summary]
    meta = opts |> Keyword.get(:meta, []) |> Enum.reject(&(&1 in [nil, ""]))
    status = status(tool)

    prefix = [
      Theme.fg(theme, :tool_icon, Theme.symbol(theme, :tool_icon)),
      " ",
      Theme.bold(to_string(name))
    ]

    suffix = ["  ", status_icon(status, theme)]

    headline =
      fitted_headline(
        summary,
        meta,
        Keyword.get(opts, :summary_style),
        prefix,
        action,
        suffix,
        width,
        theme
      )

    text = [
      prefix,
      if(action in [nil, ""], do: "", else: [" ", action]),
      if(headline in [nil, ""],
        do: "",
        else: [Theme.symbol(theme, :separator), headline]
      ),
      suffix
    ]

    Theme.fg(theme, :tool_title, text)
  end

  defp format_summary(summary, :elixir_dim) when is_binary(summary),
    do: Syntax.highlight_inline_elixir(summary)

  defp format_summary(summary, _style), do: summary

  defp fitted_headline(summary, meta, summary_style, prefix, action, suffix, width, theme) do
    summary = format_summary(summary, summary_style)
    meta = Enum.map(meta, &Theme.fg(theme, :muted, &1))
    headline = join_headline(summary, meta, theme)

    cond do
      headline in [nil, "", []] ->
        headline

      is_nil(width) ->
        headline

      true ->
        fit_headline(summary, meta, prefix, action, suffix, width, theme)
    end
  end

  defp join_headline(summary, meta, theme) do
    [summary | meta]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.intersperse([" ", Theme.fg(theme, :muted, "·"), " "])
  end

  defp fit_headline(summary, meta, prefix, action, suffix, width, theme) do
    separator_width = Width.visible_length(Theme.symbol(theme, :separator))
    action_width = if action in [nil, ""], do: 0, else: Width.visible_length([" ", action])

    available =
      width - Width.visible_length(prefix) - action_width - Width.visible_length(suffix) -
        separator_width

    cond do
      available <= 0 ->
        nil

      meta == [] ->
        Widget.fit_line(summary, available, ellipsis?: true)

      summary in [nil, ""] ->
        Widget.fit_line(join_headline(nil, meta, theme), available, ellipsis?: true)

      true ->
        meta_tail = [
          " ",
          Theme.fg(theme, :muted, "·"),
          " ",
          Enum.intersperse(meta, [" ", Theme.fg(theme, :muted, "·"), " "])
        ]

        summary_available = available - Width.visible_length(meta_tail)

        if summary_available > 0 do
          [Widget.fit_line(summary, summary_available, ellipsis?: true), meta_tail]
        else
          Widget.fit_line(join_headline(summary, meta, theme), available, ellipsis?: true)
        end
    end
  end

  def generic_lines(tool, width, theme),
    do: block(tool, width, theme, summary: compact_summary(tool))

  def compact_summary(tool) do
    cond do
      args = params(tool) -> summarize_value(args, 80)
      output = output(tool) -> summarize_value(output, 80)
      true -> nil
    end
  end

  def summarize_value(value, :infinity) when is_binary(value), do: single_line(value)

  def summarize_value(value, :infinity) do
    value |> inspect(limit: :infinity) |> single_line()
  end

  def summarize_value(value, limit) when is_binary(value) do
    value |> single_line() |> String.slice(0, limit)
  end

  def summarize_value(value, limit) do
    value |> inspect(limit: 8) |> single_line() |> String.slice(0, limit)
  end

  def single_line(value) when is_binary(value), do: String.replace(value, "\n", " ")

  def status_bg(text, status, theme) when status in [:ok, "ok", :success, "success"],
    do: Theme.bg(theme, :tool_success_bg, text)

  def status_bg(text, :error, theme),
    do: Theme.bg(theme, :tool_error_bg, text)

  def status_bg(text, _status, theme), do: Theme.bg(theme, :tool_pending_bg, text)

  def status(tool), do: tool |> Map.get(:status, :running) |> normalize_status()

  def status_icon(status, theme) when status in [:ok, :success],
    do: Theme.fg(theme, :success, Theme.symbol(theme, :success_icon))

  def status_icon(:error, theme),
    do: Theme.fg(theme, :error, Theme.symbol(theme, :error_icon))

  def status_icon(_status, theme), do: Theme.fg(theme, :muted, Theme.symbol(theme, :running_icon))

  def params(tool), do: Map.get(tool, :args) || Map.get(tool, :params)

  def output(tool) do
    tool
    |> raw_output()
    |> unwrap_output()
  end

  def format_value(value) when is_binary(value), do: value
  def format_value(value), do: inspect(value, pretty: true, limit: 20)

  def error_lines(error, width, theme) do
    error
    |> format_error()
    |> plain_lines(width, theme, fg: :error)
  end

  def plain_lines(value, width, theme, opts \\ []) do
    fg = Keyword.get(opts, :fg, :tool_output)

    value
    |> format_value()
    |> String.split("\n")
    |> Enum.flat_map(&plain_line(&1, width, theme, fg: fg))
  end

  def plain_line(line, width, theme, opts \\ []) do
    fg = Keyword.get(opts, :fg, :tool_output)
    wrap_output_line(Theme.fg(theme, fg, line), width)
  end

  def inspect_lines(value, width, theme) do
    value
    |> format_value()
    |> String.split("\n")
    |> Enum.flat_map(&inspect_line(&1, width, theme))
  end

  def inspect_line(line, width, _theme) do
    line
    |> Syntax.highlight_elixir()
    |> output_line(width)
  end

  def output_line(line, width), do: wrap_output_line(line, width)

  def source_lines(lines, language, width, theme),
    do: SourceBlock.source_lines(lines, language, width, theme)

  defp display_body_lines(%Display{body: body, truncate?: truncate?}, width, theme) do
    body
    |> Enum.flat_map(&display_block_lines(&1, width, theme, truncate?))
    |> trim_trailing_blank()
    |> case do
      [] -> nil
      lines -> lines
    end
  end

  defp display_block_lines({:text, text, opts}, width, theme, truncate?),
    do: text_block_lines(text, width, theme, :text, truncate?, opts)

  defp display_block_lines({:inspect, text, opts}, width, theme, truncate?),
    do: text_block_lines(text, width, theme, :inspect, truncate?, opts)

  defp display_block_lines({:error, text, opts}, width, theme, truncate?),
    do: text_block_lines(text, width, theme, :error, truncate?, opts)

  defp display_block_lines({:source, source, opts}, width, theme, truncate?),
    do: source_block_lines(source, width, theme, truncate?, opts)

  defp display_block_lines({:diff, diff, opts}, width, theme, truncate?),
    do: diff_block_lines(diff, width, theme, truncate?, opts)

  defp display_block_lines({:image, %Content.Image{} = image, _opts}, width, theme, _truncate?) do
    image
    |> Image.new(max_width_cells: 80)
    |> Image.render(width, theme)
  end

  defp display_block_lines({:markdown, markdown, opts}, width, theme, truncate?) do
    truncation = line_window(markdown, truncate?, opts)

    lines =
      truncation.lines
      |> Enum.join("\n")
      |> Markdown.render(max(width - 2, 1), theme)
      |> Enum.map(&[Widget.spaces(2), &1])
      |> maybe_append_hint(truncation, theme, width, Keyword.get(opts, :truncation, :head))
      |> maybe_append_read_limit_footer(truncation, opts, theme)

    Lines.join(lines, [""])
  end

  defp display_block_lines({:lines, lines, _opts}, _width, _theme, _truncate?),
    do: Lines.join(lines || [], [""])

  defp display_block_lines({:render, renderer, _opts}, width, theme, _truncate?)
       when is_function(renderer, 2) do
    renderer.(width, theme) || []
  end

  defp text_block_lines(text, width, theme, kind, truncate?, opts) do
    truncation = line_window(text, truncate?, opts)

    lines =
      truncation.lines
      |> Enum.flat_map(&render_text_line(&1, kind, width, theme))
      |> maybe_append_hint(truncation, theme, width, Keyword.get(opts, :truncation, :head))

    Lines.join(lines, [""])
  end

  defp source_block_lines(source, width, theme, truncate?, opts) do
    truncation = line_window(source, truncate?, opts)
    language = Keyword.get(opts, :language)

    lines =
      truncation.lines
      |> source_lines(language, width, theme)
      |> maybe_append_hint(truncation, theme, width, Keyword.get(opts, :truncation, :head))
      |> maybe_append_read_limit_footer(truncation, opts, theme)

    Lines.join(lines, [""])
  end

  defp diff_block_lines(diff, width, theme, truncate?, opts) do
    truncation = line_window(diff, truncate?, opts)
    language = Keyword.get(opts, :language)

    lines =
      truncation.lines
      |> DiffBlock.diff_lines(language, width, theme)
      |> maybe_append_hint(truncation, theme, width, Keyword.get(opts, :truncation, :head))

    Lines.join(lines, [""])
  end

  defp line_window(text, truncate?, opts) do
    text
    |> format_value()
    |> String.split("\n")
    |> TextTruncation.lines(
      enabled?: truncate?,
      limit: 8,
      mode: Keyword.get(opts, :truncation, :head)
    )
  end

  defp render_text_line(line, :inspect, width, theme), do: inspect_line(line, width, theme)

  defp render_text_line(line, :error, width, theme),
    do: plain_line(line, width, theme, fg: :error)

  defp render_text_line(line, _kind, width, theme), do: plain_line(line, width, theme)

  defp maybe_append_hint(lines, %{truncated?: false}, _theme, _width, _mode), do: lines

  defp maybe_append_hint(lines, %{omitted: omitted}, theme, width, :tail) do
    [TextTruncation.hint(omitted, theme, width), ""] |> Lines.join(lines)
  end

  defp maybe_append_hint(lines, %{omitted: omitted}, theme, width, _mode) do
    lines |> Lines.join([""]) |> Lines.join([TextTruncation.hint(omitted, theme, width)])
  end

  defp maybe_append_read_limit_footer(lines, %{truncated?: true}, _opts, _theme), do: lines

  defp maybe_append_read_limit_footer(lines, _truncation, opts, theme) do
    if Keyword.get(opts, :read_limit_truncated?, false) do
      lines
      |> Lines.join([""])
      |> Lines.join([
        [Widget.spaces(2), Theme.fg(theme, :muted, "… file truncated by read limit")]
      ])
    else
      lines
    end
  end

  defp trim_trailing_blank(lines),
    do: Enum.reverse(lines) |> Enum.drop_while(&(&1 == "")) |> Enum.reverse()

  defp wrap_output_line(line, width) do
    line
    |> Widget.wrap(max(width - 2, 1))
    |> Enum.map(&[Widget.spaces(2), &1])
  end

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

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error, pretty: true, limit: 20)

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

  defp tool_name(tool), do: Map.get(tool, :name)

  defp normalize_status(:success), do: :ok
  defp normalize_status(status), do: status
end
