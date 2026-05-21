defmodule Vibe.Plugins.WebSearch.SearchItem do
  @moduledoc """
  Normalized web search result item.
  """

  @type t :: %__MODULE__{
          title: String.t(),
          url: String.t() | nil,
          author: String.t() | nil,
          published_at: String.t() | nil,
          text: String.t(),
          highlights: [String.t()],
          summary: String.t() | nil,
          score: number() | nil,
          metadata: map()
        }

  defstruct title: "Untitled",
            url: nil,
            author: nil,
            published_at: nil,
            text: "",
            highlights: [],
            summary: nil,
            score: nil,
            metadata: %{}
end
