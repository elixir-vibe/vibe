defmodule Vibe.Terminal.Markdown do
  @moduledoc """
  Terminal renderer for Markdown, including MDEx streaming documents.
  """

  alias Vibe.Terminal.Markdown.Mermaid
  alias Vibe.Terminal.{Layout, Theme, Width}

  @mdex_options [extension: [table: true, strikethrough: true, tasklist: true, autolink: true]]

  @type stream_state :: MDEx.Document.t()

  @spec new_stream() :: stream_state()
  def new_stream, do: MDEx.new([{:streaming, true} | @mdex_options])

  @spec put_chunk(stream_state(), String.t()) :: stream_state()
  def put_chunk(document, chunk), do: MDEx.Document.put_markdown(document, chunk)

  @spec render_stream(stream_state(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render_stream(document, width, theme \\ Theme.default()) do
    document |> MDEx.Document.run() |> render_document(width, theme, streaming?: true)
  end

  @spec render(String.t(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render(markdown, width, theme \\ Theme.default()) when is_binary(markdown) do
    markdown
    |> MDEx.parse_document!(@mdex_options)
    |> render_document(width, theme)
  end

  @spec render_document(MDEx.Document.t(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render_document(document, width, theme, opts \\ [])

  def render_document(%MDEx.Document{nodes: nodes}, width, theme, opts) do
    nodes
    |> Enum.flat_map(&block(&1, width, theme, opts))
    |> trim_trailing_blank()
    |> case do
      [] -> [""]
      lines -> lines
    end
  end

  defp block(%MDEx.Heading{level: 1, nodes: nodes}, width, theme, _opts) do
    title = theme |> Theme.fg(:accent, inline(nodes, theme)) |> Theme.bold()

    underline =
      Theme.fg(theme, :border, String.duplicate(Theme.symbol(theme, :section_line), width))

    Layout.wrap(title, width) |> join_lines([underline, ""])
  end

  defp block(%MDEx.Heading{nodes: nodes}, width, theme, _opts) do
    title = theme |> Theme.fg(:accent, inline(nodes, theme)) |> Theme.bold()
    Layout.wrap(title, width) |> append_blank()
  end

  defp block(%MDEx.Paragraph{nodes: nodes}, width, theme, _opts),
    do: inline(nodes, theme) |> Layout.wrap(width) |> append_blank()

  defp block(%MDEx.CodeBlock{literal: literal, info: info}, width, theme, _opts) do
    language = if info in [nil, ""], do: nil, else: String.trim(info)

    if mermaid?(language) do
      case Mermaid.render(literal, width) do
        {:ok, lines} -> Enum.map(lines, &Theme.fg(theme, :text, &1)) |> append_blank()
        :error -> code_block(literal, language, width, theme)
      end
    else
      code_block(literal, language, width, theme)
    end
  end

  defp block(%MDEx.BlockQuote{nodes: nodes}, width, theme, opts) do
    nodes
    |> Enum.flat_map(&block(&1, max(width - 2, 1), theme, opts))
    |> trim_trailing_blank()
    |> Enum.map(&[Theme.fg(theme, :border, "│ "), Theme.fg(theme, :thinking_text, &1)])
    |> append_blank()
  end

  defp block(%MDEx.List{nodes: items, list_type: type}, width, theme, opts) do
    items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {item, index} ->
      render_list_item_node(item, type, index, width, theme, opts)
    end)
    |> append_blank()
  end

  defp block(%MDEx.Table{nodes: rows}, width, theme, opts),
    do: table(rows, width, theme, opts) |> append_blank()

  defp block(%MDEx.ThematicBreak{}, width, theme, _opts) do
    [Theme.fg(theme, :border, String.duplicate(Theme.symbol(theme, :section_line), width)), ""]
  end

  defp block(%{nodes: nodes}, width, theme, opts) when is_list(nodes),
    do: Enum.flat_map(nodes, &block(&1, width, theme, opts))

  defp block(%{literal: literal}, width, theme, _opts) when is_binary(literal),
    do: Layout.wrap(literal, width) |> Enum.map(&Theme.fg(theme, :text, &1))

  defp block(_node, _width, _theme, _opts), do: []

  defp code_block(literal, language, width, theme) do
    line = Theme.symbol(theme, :section_line)
    border = Theme.fg(theme, :border, String.duplicate(line, width))

    header =
      if language do
        label = Theme.fg(theme, :muted, language)
        fill = String.duplicate(line, max(width - Width.visible_length(label) - 1, 0))
        [[label, " ", Theme.fg(theme, :border, fill)]]
      else
        [border]
      end

    body =
      literal
      |> String.trim_trailing("\n")
      |> highlight_code_block(language, theme)
      |> IO.iodata_to_binary()
      |> String.split("\n")
      |> Enum.flat_map(fn line ->
        Layout.wrap(["  ", line], width)
      end)

    header |> join_lines(body) |> join_lines([border]) |> append_blank()
  end

  defp mermaid?(nil), do: false
  defp mermaid?(language), do: String.downcase(language) == "mermaid"

  defp render_list_item_node(
         %MDEx.TaskItem{nodes: nodes, checked: checked},
         _type,
         _index,
         width,
         theme,
         opts
       ) do
    marker = if checked, do: "[x]", else: "[ ]"
    render_list_item(nodes, marker, width, theme, opts)
  end

  defp render_list_item_node(%MDEx.ListItem{nodes: nodes}, type, index, width, theme, opts) do
    bullet = if type == :ordered, do: "#{index}.", else: Theme.symbol(theme, :status_icon)
    render_list_item(nodes, bullet, width, theme, opts)
  end

  defp render_list_item_node(%{nodes: nodes}, type, index, width, theme, opts)
       when is_list(nodes) do
    bullet = if type == :ordered, do: "#{index}.", else: Theme.symbol(theme, :status_icon)
    render_list_item(nodes, bullet, width, theme, opts)
  end

  defp render_list_item_node(node, _type, _index, width, theme, opts) do
    block(node, width, theme, opts)
  end

  defp render_list_item(nodes, bullet, width, theme, opts) do
    prefix = [Theme.fg(theme, :accent, bullet), " "]
    indent = Layout.spaces(Width.visible_length(prefix))

    lines =
      nodes
      |> Enum.flat_map(&block(&1, max(width - Width.visible_length(prefix), 1), theme, opts))
      |> trim_trailing_blank()
      |> maybe_keep_list_item_margin(nodes)

    case lines do
      [] -> [prefix]
      [first | rest] -> [[prefix, first] | Enum.map(rest, &[indent, &1])]
    end
  end

  defp maybe_keep_list_item_margin(lines, nodes) do
    if complex_list_item?(nodes), do: Vibe.Terminal.Lines.append(lines, ""), else: lines
  end

  defp complex_list_item?([%MDEx.Paragraph{}]), do: false
  defp complex_list_item?(_nodes), do: true

  defp table([], _width, _theme, _opts), do: []
  defp table([_row], _width, _theme, _opts), do: []

  defp table(rows, width, theme, opts) do
    cells = Enum.map(rows, &table_row(&1, theme))
    widths = column_widths(cells, width, opts)

    rows =
      cells
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, index} ->
        lines = table_lines(row, widths, theme, index == 0)

        if index == 0 do
          Vibe.Terminal.Lines.append(lines, table_separator(widths, theme))
        else
          lines
        end
      end)

    rows
    |> then(&[table_top(widths, theme) | &1])
    |> Vibe.Terminal.Lines.append(table_bottom(widths, theme))
  end

  defp table_row(%MDEx.TableRow{nodes: cells}, theme),
    do: Enum.map(cells, &inline(Map.get(&1, :nodes, []), theme))

  defp column_widths(rows, width, opts) do
    if opts[:streaming?] do
      streaming_column_widths(rows, width)
    else
      compact_column_widths(rows, width)
    end
  end

  defp compact_column_widths(rows, width) do
    columns = rows |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)
    border_width = max(columns - 1, 0) * 3 + 4
    available = max(width - border_width, columns)

    row_arrays = Enum.map(rows, &:array.from_list/1)

    0..max(columns - 1, 0)
    |> Enum.map(fn index ->
      row_arrays
      |> Enum.map(fn row -> row |> array_get(index, "") |> Width.visible_length() end)
      |> Enum.max(fn -> 1 end)
      |> min(max(div(available, max(columns, 1)), 1))
    end)
  end

  defp streaming_column_widths(rows, width) do
    columns = rows |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)
    border_width = max(columns - 1, 0) * 3 + 4
    available = max(width - border_width, columns)
    column_count = max(columns, 1)
    base = max(div(available, column_count), 1)
    extra = rem(available, column_count)

    0..max(columns - 1, 0)
    |> Enum.map(fn index -> base + if(index < extra, do: 1, else: 0) end)
  end

  defp highlight_code_block(code, nil, theme), do: Theme.fg(theme, :tool_output, code)

  defp highlight_code_block(code, language, theme) do
    {:ok, highlighted} = Lumis.highlight(code, formatter: {:terminal, language: language})
    highlighted
  rescue
    _error -> Theme.fg(theme, :tool_output, code)
  end

  defp table_lines(row, widths, theme, header?) do
    row = :array.from_list(row)

    cells =
      widths
      |> Enum.with_index()
      |> Enum.map(fn {width, index} ->
        table_cell_lines(array_get(row, index, ""), width, theme, header?)
      end)

    height = cells |> Enum.map(&length/1) |> Enum.max(fn -> 1 end)

    0..(height - 1)
    |> Enum.map(fn line_index ->
      row_cells =
        cells
        |> Enum.map(&:array.from_list/1)
        |> Enum.zip(widths)
        |> Enum.map(fn {cell, width} ->
          array_get(cell, line_index, Layout.pad_line("", width))
        end)
        |> Enum.intersperse(Theme.fg(theme, :border, " │ "))

      [Theme.fg(theme, :border, "│ "), row_cells, Theme.fg(theme, :border, " │")]
    end)
  end

  defp array_get(array, index, default) do
    if index < :array.size(array), do: :array.get(index, array), else: default
  end

  defp table_cell_lines(cell, width, theme, header?) do
    cell
    |> Layout.wrap(width)
    |> Enum.map(fn line ->
      padded = Layout.pad_line(line, width)
      if header?, do: Theme.bold(Theme.fg(theme, :accent, padded)), else: padded
    end)
  end

  defp table_top(widths, theme) do
    parts = widths |> Enum.map(&String.duplicate("─", &1)) |> Enum.intersperse("─┬─")
    Theme.fg(theme, :border, ["╭─", parts, "─╮"])
  end

  defp table_separator(widths, theme) do
    parts = widths |> Enum.map(&String.duplicate("─", &1)) |> Enum.intersperse("─┼─")
    Theme.fg(theme, :border, ["├─", parts, "─┤"])
  end

  defp table_bottom(widths, theme) do
    parts = widths |> Enum.map(&String.duplicate("─", &1)) |> Enum.intersperse("─┴─")
    Theme.fg(theme, :border, ["╰─", parts, "─╯"])
  end

  defp inline(nodes, theme) when is_list(nodes), do: Enum.map(nodes, &inline(&1, theme))
  defp inline(%MDEx.Text{literal: literal}, _theme), do: literal

  defp inline(%MDEx.Code{literal: literal}, theme), do: Theme.fg(theme, :tool_title, literal)

  defp inline(%MDEx.Strong{nodes: nodes}, theme), do: nodes |> inline(theme) |> Theme.bold()
  defp inline(%MDEx.Emph{nodes: nodes}, theme), do: nodes |> inline(theme) |> Theme.italic()

  defp inline(%MDEx.Link{nodes: nodes, url: url}, theme) do
    text = inline(nodes, theme)
    link_text = IO.iodata_to_binary(List.wrap(text))

    if hyperlinks?() and link_text != url do
      [osc8_open(url), Theme.fg(theme, :accent, text), osc8_close()]
    else
      Theme.fg(theme, :accent, [text, " (", url, ")"])
    end
  end

  defp inline(%MDEx.SoftBreak{}, _theme), do: "\n"
  defp inline(%MDEx.LineBreak{}, _theme), do: "\n"
  defp inline(%{nodes: nodes}, theme) when is_list(nodes), do: inline(nodes, theme)
  defp inline(%{literal: literal}, _theme) when is_binary(literal), do: literal
  defp inline(_node, _theme), do: ""

  defp join_lines(left, right), do: Vibe.Terminal.Lines.join(left, right)
  defp append_blank(lines), do: Vibe.Terminal.Lines.append(lines, "")

  defp trim_trailing_blank(lines),
    do: Enum.reverse(lines) |> Enum.drop_while(&(&1 == "")) |> Enum.reverse()

  defp hyperlinks? do
    case Application.get_env(:vibe, :tui_hyperlinks) do
      nil -> Vibe.Terminal.Image.capabilities().hyperlinks?
      value -> value
    end
  end

  defp osc8_open(url), do: ["\e]8;;", url, "\e\\"]
  defp osc8_close, do: "\e]8;;\e\\"
end
