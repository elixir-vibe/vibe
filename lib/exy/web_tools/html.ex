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
        |> Enum.map(&node_to_markdown/1)
        |> IO.iodata_to_binary()
        |> cleanup_markdown()

      {:ok, markdown}
    end
  end

  defp parse_or_document(%FetchResult{} = result), do: parse(result)
  defp parse_or_document(value) when is_binary(value), do: parse(value)
  defp parse_or_document(value) when is_list(value), do: {:ok, value}

  defp node_to_markdown({"script", _attrs, _children}), do: []
  defp node_to_markdown({"style", _attrs, _children}), do: []
  defp node_to_markdown({"noscript", _attrs, _children}), do: []
  defp node_to_markdown({"br", _attrs, _children}), do: "\n"
  defp node_to_markdown({"hr", _attrs, _children}), do: "\n\n---\n\n"

  defp node_to_markdown({tag, _attrs, children})
       when tag in ["h1", "h2", "h3", "h4", "h5", "h6"] do
    level = tag |> String.trim_leading("h") |> String.to_integer()
    ["\n\n", String.duplicate("#", level), " ", children_to_markdown(children), "\n\n"]
  end

  defp node_to_markdown({tag, _attrs, children})
       when tag in ["p", "div", "section", "article", "main", "header", "footer"] do
    ["\n\n", children_to_markdown(children), "\n\n"]
  end

  defp node_to_markdown({tag, _attrs, children}) when tag in ["strong", "b"] do
    ["**", children_to_markdown(children), "**"]
  end

  defp node_to_markdown({tag, _attrs, children}) when tag in ["em", "i"] do
    ["*", children_to_markdown(children), "*"]
  end

  defp node_to_markdown({"code", _attrs, children}),
    do: ["`", children_to_markdown(children), "`"]

  defp node_to_markdown({"pre", _attrs, children}) do
    ["\n\n```\n", children_to_markdown(children), "\n```\n\n"]
  end

  defp node_to_markdown({"a", attrs, children}) do
    text = children_to_markdown(children) |> IO.iodata_to_binary() |> String.trim()
    href = attr(attrs, "href")

    if href in [nil, ""] do
      text
    else
      ["[", text, "](", href, ")"]
    end
  end

  defp node_to_markdown({"li", _attrs, children}),
    do: ["- ", children_to_markdown(children), "\n"]

  defp node_to_markdown({_tag, _attrs, children}), do: children_to_markdown(children)
  defp node_to_markdown(text) when is_binary(text), do: text
  defp node_to_markdown(_node), do: []

  defp children_to_markdown(children), do: Enum.map(children, &node_to_markdown/1)

  defp cleanup_markdown(markdown) do
    markdown
    |> String.replace(~r/[ \t]+\n/, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
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
