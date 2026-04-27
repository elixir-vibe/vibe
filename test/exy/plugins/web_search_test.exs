defmodule Exy.Plugins.WebSearchTest do
  use ExUnit.Case, async: true

  test "exposes pipeable eval API" do
    assert [%Exy.Plugin.API{alias: Web, module: Exy.Plugins.WebSearch.API}] =
             Exy.Plugins.WebSearch.apis([])
  end

  test "search results render through markdown protocol" do
    result = %Exy.Plugins.WebSearch.Result{
      title: "Ecto",
      url: "https://hexdocs.pm/ecto",
      summary: "Database wrapper",
      text: "Docs"
    }

    markdown = Exy.Markdown.to_markdown(result)

    assert markdown =~ "### [Ecto](https://hexdocs.pm/ecto)"
    assert markdown =~ "Database wrapper"
  end
end
