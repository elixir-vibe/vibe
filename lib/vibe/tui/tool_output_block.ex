defmodule Vibe.TUI.ToolOutputBlock do
  @moduledoc "Renders structured tool display body blocks for TUI tool cards."

  alias Vibe.Model.Content
  alias Vibe.Tool.Display

  alias Vibe.TUI.{
    DiffBlock,
    Lines,
    Markdown,
    SourceBlock,
    TextTruncation,
    Theme,
    ValueFormat,
    Widget
  }

  alias Vibe.TUI.Widgets.Image

  @spec display_body_lines(Display.t(), pos_integer(), Theme.t()) :: [IO.chardata()] | nil
  def display_body_lines(%Display{body: body, truncate?: truncate?}, width, theme) do
    body
    |> Enum.flat_map(&display_block_lines(&1, width, theme, truncate?))
    |> trim_trailing_blank()
    |> case do
      [] -> nil
      lines -> lines
    end
  end

  @spec display_block_lines(tuple(), pos_integer(), Theme.t(), boolean()) :: [IO.chardata()]
  def display_block_lines({:text, text, opts}, width, theme, truncate?),
    do: text_block_lines(text, width, theme, :text, truncate?, opts)

  def display_block_lines({:inspect, text, opts}, width, theme, truncate?),
    do: text_block_lines(text, width, theme, :inspect, truncate?, opts)

  def display_block_lines({:error, text, opts}, width, theme, truncate?),
    do: text_block_lines(text, width, theme, :error, truncate?, opts)

  def display_block_lines({:source, source, opts}, width, theme, truncate?),
    do: source_block_lines(source, width, theme, truncate?, opts)

  def display_block_lines({:diff, diff, opts}, width, theme, truncate?),
    do: diff_block_lines(diff, width, theme, truncate?, opts)

  def display_block_lines({:image, %Content.Image{} = image, _opts}, width, theme, _truncate?) do
    image
    |> Image.new(max_width_cells: 80)
    |> Image.render(width, theme)
  end

  def display_block_lines({:markdown, markdown, opts}, width, theme, truncate?) do
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

  def display_block_lines({:lines, lines, _opts}, _width, _theme, _truncate?),
    do: Lines.join(lines || [], [""])

  def display_block_lines({:render, renderer, _opts}, width, theme, _truncate?)
      when is_function(renderer, 2) do
    renderer.(width, theme) || []
  end

  @spec text_block_lines(
          term(),
          pos_integer(),
          Theme.t(),
          :text | :inspect | :error,
          boolean(),
          keyword()
        ) :: [IO.chardata()]
  def text_block_lines(text, width, theme, kind, truncate?, opts) do
    truncation = line_window(text, truncate?, opts)

    lines =
      truncation.lines
      |> Enum.flat_map(&render_text_line(&1, kind, width, theme))
      |> maybe_append_hint(truncation, theme, width, Keyword.get(opts, :truncation, :head))

    Lines.join(lines, [""])
  end

  @spec source_block_lines(term(), pos_integer(), Theme.t(), boolean(), keyword()) :: [
          IO.chardata()
        ]
  def source_block_lines(source, width, theme, truncate?, opts) do
    truncation = line_window(source, truncate?, opts)
    language = Keyword.get(opts, :language)

    lines =
      truncation.lines
      |> SourceBlock.source_lines(language, width, theme)
      |> maybe_append_hint(truncation, theme, width, Keyword.get(opts, :truncation, :head))
      |> maybe_append_read_limit_footer(truncation, opts, theme)

    Lines.join(lines, [""])
  end

  @spec diff_block_lines(term(), pos_integer(), Theme.t(), boolean(), keyword()) :: [
          IO.chardata()
        ]
  def diff_block_lines(diff, width, theme, truncate?, opts) do
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
    |> ValueFormat.format()
    |> String.split("\n")
    |> TextTruncation.lines(
      enabled?: truncate?,
      limit: 8,
      mode: Keyword.get(opts, :truncation, :head)
    )
  end

  defp render_text_line(line, :inspect, width, theme),
    do: ValueFormat.inspect_line(line, width, theme)

  defp render_text_line(line, :error, width, theme),
    do: ValueFormat.plain_line(line, width, theme, fg: :error)

  defp render_text_line(line, _kind, width, theme), do: ValueFormat.plain_line(line, width, theme)

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
end
