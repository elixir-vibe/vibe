defmodule Vibe.Storage.Search.Result do
  @moduledoc "Typed FTS search result with ranking and snippets."
  @type source :: :session | :memory

  @type t :: %__MODULE__{
          source: source(),
          id: String.t(),
          owner_id: String.t() | nil,
          title: String.t() | nil,
          text: String.t(),
          snippet: String.t() | nil,
          snippet_parts: [snippet_part()],
          rank: number() | nil,
          at: DateTime.t() | nil,
          metadata: map()
        }

  @type snippet_part :: %{text: String.t(), highlight?: boolean()}

  defstruct [
    :source,
    :id,
    :owner_id,
    :title,
    :text,
    :snippet,
    :rank,
    :at,
    metadata: %{},
    snippet_parts: []
  ]
end
