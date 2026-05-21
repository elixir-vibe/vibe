defimpl Vibe.Markdown, for: Vibe.Plugins.WebSearch.Result do
  @moduledoc "Markdown rendering for WebSearch plugin results."

  def to_markdown(result) do
    Vibe.WebTools.SearchItemRenderer.render(%{
      title: result.title,
      url: result.url,
      author: result.author,
      date: result.published_date,
      summary: result.summary,
      highlights: result.highlights,
      text: result.text
    })
  end
end
