defmodule Exy.Plugins.WebSearch do
  @moduledoc false

  use Exy.Plugin

  @impl true
  def apis(_state) do
    [
      %Exy.Plugin.API{
        name: :web_search,
        module: Exy.Plugins.WebSearch.API,
        alias: Web,
        description: "Composable Exa web search API for eval sessions",
        examples: ["Web.search(\"ecto sqlite fts\") |> Web.format()"]
      }
    ]
  end
end
