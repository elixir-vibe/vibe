defmodule Vibe.Plugins.WebSearch.Presentation.MarkdownTest do
  use ExUnit.Case, async: true

  test "renders plugin search results as Markdown" do
    result = %Vibe.Plugins.WebSearch.Result{
      title: "Ecto",
      url: "https://hexdocs.pm/ecto",
      summary: "Database wrapper",
      text: "Docs"
    }

    markdown = Vibe.Markdown.to_markdown(result)

    assert markdown =~ "### [Ecto](https://hexdocs.pm/ecto)"
    assert markdown =~ "Database wrapper"
  end
end
