defmodule Exy.WebTools.HTML do
  @moduledoc """
  HTML parsing and extraction helpers for `Exy.WebTools`.

  This module intentionally delegates HTML parsing to Floki. It does not parse
  HTML with regular expressions.
  """

  alias Exy.WebTools.FetchResult

  @type html_tree :: Floki.html_tree()

  @doc "Parses HTML from a fetch result or binary string with Floki."
  @spec parse(FetchResult.t() | String.t()) :: {:ok, html_tree()} | {:error, term()}
  def parse(%FetchResult{text: html}), do: parse(html)

  def parse(html) when is_binary(html) do
    case Floki.parse_document(html) do
      {:ok, document} -> {:ok, document}
      {:error, reason} -> {:error, {:invalid_html, reason}}
    end
  end

  @doc "Parses HTML with Floki and raises when parsing fails."
  @spec parse!(FetchResult.t() | String.t()) :: html_tree()
  def parse!(value) do
    case parse(value) do
      {:ok, document} -> document
      {:error, reason} -> raise ArgumentError, "invalid HTML: #{inspect(reason)}"
    end
  end

  @doc "Returns raw HTML for nodes matching a CSS selector."
  @spec select_html(FetchResult.t() | String.t() | html_tree(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def select_html(value, selector) when is_binary(selector) do
    with {:ok, document} <- parse_or_document(value) do
      selected = Floki.find(document, selector)

      if selected == [] do
        {:error, {:selector_not_found, selector}}
      else
        {:ok, Enum.map_join(selected, "\n\n", &Floki.raw_html/1)}
      end
    end
  end

  @doc "Converts HTML to plain text using Floki."
  @spec to_text(FetchResult.t() | String.t() | html_tree()) ::
          {:ok, String.t()} | {:error, term()}
  def to_text(value) do
    with {:ok, document} <- parse_or_document(value) do
      {:ok, document |> Floki.text(sep: " ") |> normalize_whitespace()}
    end
  end

  @doc "Converts HTML to Markdown using a small Floki-tree renderer."
  @spec to_markdown(FetchResult.t() | String.t() | html_tree()) ::
          {:ok, String.t()} | {:error, term()}
  def to_markdown(value) do
    with {:ok, document} <- parse_or_document(value) do
      markdown =
        document
        |> render_nodes(%{list_depth: 0, in_pre?: false, in_code?: false, in_table?: false})
        |> IO.iodata_to_binary()
        |> cleanup_markdown()

      {:ok, markdown}
    end
  end

  defp parse_or_document(%FetchResult{} = result), do: parse(result)
  defp parse_or_document(value) when is_binary(value), do: parse(value)
  defp parse_or_document(value) when is_list(value), do: {:ok, value}

  defp render_nodes(nodes, context), do: Enum.map(nodes, &render_node(&1, context))

  defp render_node({tag, _attrs, _children}, _context)
       when tag in ["script", "style", "noscript", "template"],
       do: []

  defp render_node({"br", _attrs, _children}, _context), do: "\n"
  defp render_node({"hr", _attrs, _children}, _context), do: block("---")

  defp render_node({tag, _attrs, children}, context)
       when tag in ["h1", "h2", "h3", "h4", "h5", "h6"] do
    level = tag |> String.trim_leading("h") |> String.to_integer()
    block([String.duplicate("#", level), " ", inline(children, context)])
  end

  defp render_node({tag, _attrs, children}, context)
       when tag in ["p", "div", "section", "article", "main", "header", "footer"] do
    block(render_nodes(children, context))
  end

  defp render_node({"blockquote", _attrs, children}, context) do
    children
    |> render_nodes(context)
    |> IO.iodata_to_binary()
    |> String.trim()
    |> String.split("\n")
    |> Enum.map_join("\n", &["> ", &1])
    |> block()
  end

  defp render_node({tag, _attrs, children}, context) when tag in ["strong", "b"] do
    ["**", inline(children, context), "**"]
  end

  defp render_node({tag, _attrs, children}, context) when tag in ["em", "i"] do
    ["*", inline(children, context), "*"]
  end

  defp render_node({tag, _attrs, children}, context) when tag in ["del", "s", "strike"] do
    ["~~", inline(children, context), "~~"]
  end

  defp render_node({"code", _attrs, children}, %{in_pre?: true} = context),
    do: render_nodes(children, %{context | in_code?: true})

  defp render_node({"code", _attrs, children}, context),
    do: ["`", inline(children, %{context | in_code?: true}), "`"]

  defp render_node({"pre", _attrs, children}, context) do
    code =
      children
      |> render_nodes(%{context | in_pre?: true, in_code?: true})
      |> IO.iodata_to_binary()

    block(["```\n", String.trim(code), "\n```"])
  end

  defp render_node({"a", attrs, children}, context) do
    text = inline(children, context) |> IO.iodata_to_binary() |> String.trim()
    href = attr(attrs, "href")

    if href in [nil, ""] do
      text
    else
      ["[", text, "](", href, ")"]
    end
  end

  defp render_node({"img", attrs, _children}, _context) do
    src = attr(attrs, "src")
    alt = attr(attrs, "alt") || ""

    if src in [nil, ""], do: [], else: ["![", alt, "](", src, ")"]
  end

  defp render_node({"ul", _attrs, children}, context), do: render_list(children, context, :ul)

  defp render_node({"ol", attrs, children}, context) do
    start = attrs |> attr("start") |> parse_start_index()
    render_list(children, context, {:ol, start})
  end

  defp render_node({"table", _attrs, children}, context), do: render_table(children, context)

  defp render_node({_tag, _attrs, children}, context), do: render_nodes(children, context)

  defp render_node(text, %{in_code?: true}) when is_binary(text), do: text
  defp render_node(text, _context) when is_binary(text), do: text
  defp render_node(_node, _context), do: []

  defp inline(children, context) do
    children
    |> render_nodes(context)
    |> IO.iodata_to_binary()
    |> normalize_inline()
  end

  defp block(content), do: ["\n\n", content, "\n\n"]
  defp list_block(content), do: ["\n", content, "\n"]

  defp render_list(children, context, type) do
    items = Enum.filter(children, &match?({"li", _attrs, _children}, &1))

    items
    |> Enum.with_index(list_start(type))
    |> Enum.map(fn {{"li", _attrs, item_children}, index} ->
      marker = list_marker(type, index)
      nested? = context.list_depth > 0
      indent = String.duplicate("  ", context.list_depth)
      indent = if nested?, do: indent, else: ""
      {nested, inline_children} = Enum.split_with(item_children, &list_node?/1)
      nested = Enum.reverse(nested)
      inline_children = Enum.reverse(inline_children)
      body = inline_children |> render_nodes(context) |> IO.iodata_to_binary() |> String.trim()

      nested_body =
        nested
        |> render_nodes(%{context | list_depth: context.list_depth + 1})
        |> IO.iodata_to_binary()
        |> String.trim()
        |> indent_nested_list()

      nested_prefix = if nested_body == "", do: "", else: "\n"

      [
        indent,
        marker,
        indent_lines(body, indent <> String.duplicate(" ", String.length(marker))),
        nested_prefix,
        nested_body
      ]
    end)
    |> Enum.intersperse("\n")
    |> list_block()
  end

  defp render_table(children, context) do
    rows =
      children
      |> collect_table_rows()
      |> Enum.map(&table_row(&1, context))
      |> Enum.reject(&(&1 == []))

    case rows do
      [] ->
        []

      [header | body] ->
        block([table_line(header), "\n", table_separator(header), table_body(body)])
    end
  end

  defp table_body([]), do: []
  defp table_body(rows), do: ["\n", Enum.map_join(rows, "\n", &table_line/1)]

  defp collect_table_rows(nodes) do
    Enum.flat_map(nodes, fn
      {"tr", _attrs, _children} = row -> [row]
      {_tag, _attrs, children} -> collect_table_rows(children)
      _node -> []
    end)
  end

  defp table_row({"tr", _attrs, children}, context) do
    children
    |> Enum.filter(&match?({tag, _attrs, _children} when tag in ["th", "td"], &1))
    |> Enum.map(fn {_tag, _attrs, cell_children} ->
      cell_children
      |> inline(%{context | in_table?: true})
      |> String.replace("|", "\\|")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    end)
  end

  defp table_line(cells), do: ["| ", Enum.intersperse(cells, " | "), " |"]

  defp table_separator(cells),
    do: ["| ", cells |> Enum.map(fn _ -> "---" end) |> Enum.intersperse(" | "), " |"]

  defp list_start({:ol, start}), do: start
  defp list_start(_type), do: 1

  defp list_marker({:ol, _start}, index), do: "#{index}. "
  defp list_marker(_type, _index), do: "- "

  defp parse_start_index(nil), do: 1

  defp parse_start_index(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _other -> 1
    end
  end

  defp list_node?({tag, _attrs, _children}) when tag in ["ul", "ol"], do: true
  defp list_node?(_node), do: false

  defp indent_nested_list(""), do: ""

  defp indent_nested_list(text) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", &["  ", &1])
  end

  defp indent_lines(text, continuation_indent) do
    text
    |> String.split("\n")
    |> case do
      [first | rest] -> [first, Enum.map(rest, &["\n", continuation_indent, &1])]
      [] -> []
    end
  end

  defp cleanup_markdown(markdown) do
    markdown
    |> String.replace(~r/[\t ]+\n/, "\n")
    |> String.replace(~r/\n\n([\t ]+)/, "\n\\1")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.replace(~r/\n\n(?=  \s*[-*+]\s)/, "\n")
    |> String.trim()
  end

  defp normalize_inline(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/\s+([\.,;:!?\)\]])/, "\\1")
    |> String.trim()
  end

  defp normalize_whitespace(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()

  defp attr(attrs, name) do
    attrs
    |> Enum.find_value(fn
      {^name, value} -> value
      _ -> nil
    end)
  end
end
