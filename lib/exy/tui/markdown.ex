defmodule Exy.TUI.Markdown do
  @moduledoc """
  Terminal renderer for Markdown, including MDEx streaming documents.
  """

  alias Exy.TUI.{Theme, Widget, Width}

  @mdex_options [extension: [table: true, strikethrough: true, tasklist: true, autolink: true]]

  @type stream_state :: MDEx.Document.t()

  @spec new_stream() :: stream_state()
  def new_stream, do: MDEx.new([{:streaming, true} | @mdex_options])

  @spec put_chunk(stream_state(), String.t()) :: stream_state()
  def put_chunk(document, chunk), do: MDEx.Document.put_markdown(document, chunk)

  @spec render_stream(stream_state(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render_stream(document, width, theme \\ Theme.default()) do
    document |> MDEx.Document.run() |> render_document(width, theme)
  end

  @spec render(String.t(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render(markdown, width, theme \\ Theme.default()) when is_binary(markdown) do
    markdown
    |> MDEx.parse_document!(@mdex_options)
    |> render_document(width, theme)
  end

  @spec render_document(MDEx.Document.t(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render_document(%MDEx.Document{nodes: nodes}, width, theme) do
    nodes
    |> Enum.flat_map(&block(&1, width, theme))
    |> trim_trailing_blank()
    |> case do
      [] -> [""]
      lines -> lines
    end
  end

  defp block(%MDEx.Heading{level: 1, nodes: nodes}, width, theme) do
    title = theme |> Theme.fg(:accent, inline(nodes, theme)) |> Theme.bold()

    underline =
      Theme.fg(theme, :border, String.duplicate(Theme.symbol(theme, :section_line), width))

    Widget.wrap(title, width) |> join_lines([underline, ""])
  end

  defp block(%MDEx.Heading{nodes: nodes}, width, theme) do
    title = theme |> Theme.fg(:accent, inline(nodes, theme)) |> Theme.bold()
    Widget.wrap(title, width) |> append_blank()
  end

  defp block(%MDEx.Paragraph{nodes: nodes}, width, theme),
    do: inline(nodes, theme) |> Widget.wrap(width) |> append_blank()

  defp block(%MDEx.CodeBlock{literal: literal, info: info}, width, theme) do
    language = if info in [nil, ""], do: nil, else: String.trim(info)
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
      |> String.split("\n")
      |> Enum.flat_map(fn line ->
        Widget.wrap(["  ", highlight_code(line, language, theme)], width)
      end)

    header |> join_lines(body) |> join_lines([border]) |> append_blank()
  end

  defp block(%MDEx.BlockQuote{nodes: nodes}, width, theme) do
    nodes
    |> Enum.flat_map(&block(&1, max(width - 2, 1), theme))
    |> Enum.map(&[Theme.fg(theme, :border, "│ "), Theme.fg(theme, :thinking_text, &1)])
    |> append_blank()
  end

  defp block(%MDEx.List{nodes: items, list_type: type}, width, theme) do
    items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {item, index} ->
      render_list_item_node(item, type, index, width, theme)
    end)
    |> append_blank()
  end

  defp block(%MDEx.Table{nodes: rows}, width, theme),
    do: table(rows, width, theme) |> append_blank()

  defp block(%MDEx.ThematicBreak{}, width, theme) do
    [Theme.fg(theme, :border, String.duplicate(Theme.symbol(theme, :section_line), width)), ""]
  end

  defp block(%{nodes: nodes}, width, theme) when is_list(nodes),
    do: Enum.flat_map(nodes, &block(&1, width, theme))

  defp block(%{literal: literal}, width, theme) when is_binary(literal),
    do: Widget.wrap(literal, width) |> Enum.map(&Theme.fg(theme, :text, &1))

  defp block(_node, _width, _theme), do: []

  defp render_list_item_node(
         %MDEx.TaskItem{nodes: nodes, checked: checked},
         _type,
         _index,
         width,
         theme
       ) do
    marker = if checked, do: "[x]", else: "[ ]"
    render_list_item(nodes, marker, width, theme)
  end

  defp render_list_item_node(%MDEx.ListItem{nodes: nodes}, type, index, width, theme) do
    bullet = if type == :ordered, do: "#{index}.", else: Theme.symbol(theme, :status_icon)
    render_list_item(nodes, bullet, width, theme)
  end

  defp render_list_item_node(%{nodes: nodes}, type, index, width, theme) when is_list(nodes) do
    bullet = if type == :ordered, do: "#{index}.", else: Theme.symbol(theme, :status_icon)
    render_list_item(nodes, bullet, width, theme)
  end

  defp render_list_item_node(node, _type, _index, width, theme) do
    block(node, width, theme)
  end

  defp render_list_item(nodes, bullet, width, theme) do
    prefix = [Theme.fg(theme, :accent, bullet), " "]
    indent = Widget.spaces(Width.visible_length(prefix))

    lines =
      nodes
      |> Enum.flat_map(&block(&1, max(width - Width.visible_length(prefix), 1), theme))
      |> trim_trailing_blank()
      |> maybe_keep_list_item_margin(nodes)

    case lines do
      [] -> [prefix]
      [first | rest] -> [[prefix, first] | Enum.map(rest, &[indent, &1])]
    end
  end

  defp maybe_keep_list_item_margin(lines, nodes) do
    if complex_list_item?(nodes), do: Exy.TUI.Lines.append(lines, ""), else: lines
  end

  defp complex_list_item?([%MDEx.Paragraph{}]), do: false
  defp complex_list_item?(_nodes), do: true

  defp table(rows, width, theme) do
    cells = Enum.map(rows, &table_row(&1, theme))
    widths = column_widths(cells, width)

    rows =
      cells
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, index} ->
        line = table_line(row, widths, theme, index == 0)

        if index == 0 do
          [line, table_separator(widths, theme)]
        else
          [line]
        end
      end)

    rows
    |> then(&[table_top(widths, theme) | &1])
    |> Exy.TUI.Lines.append(table_bottom(widths, theme))
  end

  defp table_row(%MDEx.TableRow{nodes: cells}, theme),
    do: Enum.map(cells, &inline(Map.get(&1, :nodes, []), theme))

  defp column_widths(rows, width) do
    columns = rows |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)
    border_width = max(columns - 1, 0) * 3 + 4
    available = max(width - border_width, columns)

    0..max(columns - 1, 0)
    |> Enum.map(fn index ->
      rows
      |> Enum.map(fn row -> row |> Enum.at(index, "") |> Width.visible_length() end)
      |> Enum.max(fn -> 1 end)
      |> min(max(div(available, max(columns, 1)), 1))
    end)
  end

  defp highlight_code(code, nil, theme), do: Theme.fg(theme, :tool_output, code)

  defp highlight_code(code, language, theme) do
    {:ok, highlighted} = Lumis.highlight(code, formatter: {:terminal, language: language})
    highlighted
  rescue
    _error -> Theme.fg(theme, :tool_output, code)
  end

  defp table_line(row, widths, theme, header?) do
    cells =
      widths
      |> Enum.with_index()
      |> Enum.map(fn {width, index} ->
        cell = row |> Enum.at(index, "") |> Widget.pad_line(width)
        if header?, do: Theme.bold(Theme.fg(theme, :accent, cell)), else: cell
      end)
      |> Enum.intersperse(Theme.fg(theme, :border, " │ "))

    [Theme.fg(theme, :border, "│ "), cells, Theme.fg(theme, :border, " │")]
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

  defp inline(%MDEx.Link{nodes: nodes, url: url}, theme),
    do: Theme.fg(theme, :accent, [inline(nodes, theme), " (", url, ")"])

  defp inline(%MDEx.SoftBreak{}, _theme), do: "\n"
  defp inline(%MDEx.LineBreak{}, _theme), do: "\n"
  defp inline(%{nodes: nodes}, theme) when is_list(nodes), do: inline(nodes, theme)
  defp inline(%{literal: literal}, _theme) when is_binary(literal), do: literal
  defp inline(_node, _theme), do: ""

  defp join_lines(left, right), do: Exy.TUI.Lines.join(left, right)
  defp append_blank(lines), do: Exy.TUI.Lines.append(lines, "")

  defp trim_trailing_blank(lines),
    do: Enum.reverse(lines) |> Enum.drop_while(&(&1 == "")) |> Enum.reverse()
end
