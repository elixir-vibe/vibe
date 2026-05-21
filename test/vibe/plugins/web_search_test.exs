defmodule Vibe.Plugins.WebSearchTest do
  use ExUnit.Case, async: true

  alias Vibe.Plugin.API
  alias Vibe.Plugins.WebSearch.Result

  test "exposes pipeable eval API" do
    assert [%API{alias: Web, module: Vibe.Plugins.WebSearch}] =
             Vibe.Plugins.WebSearch.apis([])
  end

  test "search results render through markdown protocol" do
    result = %Result{
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
