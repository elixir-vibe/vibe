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
      "## ",
      title(result),
      "\n\n",
      metadata(result),
      "\n\n",
      body(result)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp title(%{selector: selector}) when is_binary(selector) and selector != "",
    do: "Fetched selection"

  defp title(_result), do: "Fetched page"

  defp metadata(result) do
    [
      url_line(result),
      compact_status(result),
      compact_size(result),
      selector(result),
      if(result.truncated?, do: "truncated", else: nil)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  defp url_line(%{redirected?: true, url: url, final_url: final_url}) when is_binary(final_url),
    do: "`#{final_url}` ← `#{url}`"

  defp url_line(%{url: url}), do: "`#{url}`"

  defp compact_status(result) do
    [
      result.status,
      result.format,
      meaningful_content_type(result.format, result.content_type)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" · ")
  end

  defp compact_size(result) do
    cond do
      result.total_chars && result.size_bytes ->
        "#{result.total_chars} chars"

      result.total_chars ->
        "#{result.total_chars} chars"

      result.size_bytes ->
        "#{result.size_bytes} bytes"

      true ->
        nil
    end
  end

  defp selector(%{selector: selector}) when is_binary(selector) and selector != "",
    do: "selector `#{selector}`"

  defp selector(_result), do: nil

  defp meaningful_content_type(:html, content_type) when is_binary(content_type) do
    if content_type_summary(content_type) == "text/html",
      do: nil,
      else: content_type_summary(content_type)
  end

  defp meaningful_content_type(:json, content_type) when is_binary(content_type) do
    if String.contains?(content_type, "json"), do: nil, else: content_type_summary(content_type)
  end

  defp meaningful_content_type(:markdown, _content_type), do: nil
  defp meaningful_content_type(:text, _content_type), do: nil
  defp meaningful_content_type(_format, content_type), do: content_type_summary(content_type)

  defp content_type_summary(nil), do: nil
  defp content_type_summary(""), do: nil

  defp content_type_summary(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> List.first()
  end

  defp body(%{format: :markdown, text: text}), do: text || ""

  defp body(%{format: :html, text: text}) do
    case Exy.WebTools.HTML.to_markdown(text || "") do
      {:ok, markdown} -> markdown
      {:error, _reason} -> ["```html\n", String.trim(text || ""), "\n```"]
    end
  end

  defp body(%{format: :json, text: text}), do: ["```json\n", String.trim(text || ""), "\n```"]
  defp body(%{text: text}), do: ["```text\n", String.trim(text || ""), "\n```"]
end
