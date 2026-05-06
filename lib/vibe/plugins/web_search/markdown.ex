defimpl Vibe.Markdown, for: Vibe.Plugins.WebSearch.Result do
  @moduledoc """
  Markdown rendering for WebSearch plugin results.
  """

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
      optional("Date", result.published_date),
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
    [
      "**Highlights**\n\n",
      Enum.map(values, &["- ", String.trim(&1), "\n"]),
      "\n"
    ]
  end

  defp body(nil), do: []
  defp body(""), do: []
  defp body(text), do: ["```text\n", String.trim(text), "\n```"]
end
