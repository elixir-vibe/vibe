defmodule Vibe.Plugins.WebSearch do
  @moduledoc "Web search plugin providing the `Web` eval alias."
  use Vibe.Plugin

  api(
    name: :web_search,
    module: Vibe.WebTools,
    alias: Web,
    description: "Provider-neutral web search and fetch API for eval sessions",
    examples: [
      "Web.search(\"ecto sqlite fts\") |> MD.doc()",
      "Web.fetch(\"https://hexdocs.pm/ecto\") |> MD.doc()"
    ]
  )

  @guidance """
  Use the `Web` eval alias for web search and fetch. Put network concerns in opts \
  (`provider`, `timeout`, `headers`), transformations in pipes (`Web.select!/2`, \
  `Web.truncate/2`, `Web.filter_domain/2`, `Web.take/2`). Render results with \
  `MD.doc/1`. Parse HTML with `Web.parse_html!/1` and Floki, not regexes.
  """

  @impl true
  def system_prompt(_context, state), do: {@guidance, state}
end
