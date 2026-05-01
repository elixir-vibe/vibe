defimpl Exy.Markdown, for: Exy.WebTools.SearchResult do
  @moduledoc "Markdown rendering for normalized web search results."

  def to_markdown(result) do
    [
      "## Web search: ",
      result.query,
      "\n\n",
      result.results |> Enum.map(&Exy.Markdown.to_markdown/1) |> Enum.intersperse("\n\n---\n\n")
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end
end

defimpl Exy.Markdown, for: Exy.WebTools.SearchItem do
  @moduledoc "Markdown rendering for normalized web search result items."

  def to_markdown(result) do
    [
      "### ",
      link(result.title || "Untitled", result.url),
      "\n\n",
      metadata(result),
      summary(result.summary),
      highlights(result.highlights),
      body(result.text)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp link(title, nil), do: title
  defp link(title, ""), do: title
  defp link(title, url), do: "[#{title}](#{url})"

  defp metadata(result) do
    [
      optional("Author", result.author),
      optional("Date", result.published_at),
      optional("URL", result.url)
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
  defp body(text), do: ["```text\n", String.trim(text), "\n```"]
end

defimpl Exy.Markdown, for: Exy.WebTools.FetchResult do
  @moduledoc "Markdown rendering for normalized URL fetch results."

  def to_markdown(result) do
    [
      "## Fetched URL\n\n",
      "**URL:** ",
      result.url,
      final_url(result),
      "\n\n",
      metadata(result),
      "\n\n",
      body(result)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp final_url(%{redirected?: true, final_url: final_url}) when is_binary(final_url),
    do: ["\n**Final URL:** ", final_url]

  defp final_url(_result), do: []

  defp metadata(result) do
    [
      "**Status:** #{result.status || "unknown"}",
      "**Content-Type:** #{result.content_type || "unknown"}",
      "**Format:** #{result.format}",
      "**Size:** #{result.size_bytes} bytes",
      "**Characters:** #{result.total_chars}",
      if(result.truncated?, do: "**Truncated:** true", else: nil),
      if(result.selector, do: "**Selector:** `#{result.selector}`", else: nil)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp body(%{format: :markdown, text: text}), do: text || ""
  defp body(%{format: :html, text: text}), do: ["```html\n", String.trim(text || ""), "\n```"]
  defp body(%{format: :json, text: text}), do: ["```json\n", String.trim(text || ""), "\n```"]
  defp body(%{text: text}), do: ["```text\n", String.trim(text || ""), "\n```"]
end
