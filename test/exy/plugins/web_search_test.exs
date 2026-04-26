defmodule Exy.Plugins.WebSearchTest do
  use ExUnit.Case, async: true

  test "exposes pipeable eval API" do
    assert [%Exy.Plugin.API{alias: Web, module: Exy.Plugins.WebSearch.API}] =
             Exy.Plugins.WebSearch.apis([])
  end

  test "formats search results" do
    search = %{
      query: "ecto",
      raw: %{},
      results: [
        %Exy.Plugins.WebSearch.Result{
          title: "Ecto",
          url: "https://hexdocs.pm/ecto",
          summary: "Database wrapper",
          text: "Docs"
        }
      ]
    }

    assert Exy.Plugins.WebSearch.API.format(search) =~ "Title: Ecto"
    assert Exy.Plugins.WebSearch.API.format(search) =~ "https://hexdocs.pm/ecto"
  end
end
