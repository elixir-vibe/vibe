defmodule Vibe.Plugins.WebSearch.SearchItemRenderer do
  @moduledoc "Shared Markdown rendering for URL-like search results."

  @spec render(map()) :: String.t()
  def render(item) do
    [
      "### ",
      link(item.title || "Untitled", item.url),
      "\n\n",
      metadata(item),
      summary(item.summary),
      highlights(item.highlights),
      body(item.text)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp link(title, nil), do: title
  defp link(title, ""), do: title
  defp link(title, url), do: "[#{title}](#{url})"

  defp metadata(item) do
    [
      optional("Author", item.author),
      optional("Date", item.date),
      optional("URL", item.url)
    ]
    |> Enum.reject(&(&1 == []))
    |> case do
      [] -> []
      values -> [Enum.intersperse(values, " · "), "\n\n"]
    end
  end

  defp optional(_label, nil), do: []
  defp optional(_label, ""), do: []
  defp optional(label, value), do: ["**", label, ":** ", value]

  defp summary(nil), do: []
  defp summary(""), do: []
  defp summary(text), do: [text, "\n\n"]

  defp highlights([]), do: []

  defp highlights(values) when is_list(values) do
    ["**Highlights**\n\n", Enum.map(values, &["- ", String.trim(&1), "\n"]), "\n"]
  end

  defp body(nil), do: []
  defp body(""), do: []
  defp body(text), do: Vibe.Presentation.Markdown.Fence.code_block("text", text)
end
