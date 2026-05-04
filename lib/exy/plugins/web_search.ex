defmodule Exy.Plugins.WebSearch do
  @moduledoc "Web search plugin providing the `Web` eval alias."
  use Exy.Plugin

  api(
    name: :web_search,
    module: Exy.WebTools,
    alias: Web,
    description: "Provider-neutral web search and fetch API for eval sessions",
    examples: [
      "Web.search(\"ecto sqlite fts\") |> MD.doc()",
      "Web.fetch(\"https://hexdocs.pm/ecto\") |> MD.doc()"
    ]
  )
end
