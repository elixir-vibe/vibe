defmodule Vibe.WebTools.SearchResult do
  @moduledoc """
  Normalized result for a web search request.
  """

  alias Vibe.WebTools.SearchItem

  @type t :: %__MODULE__{
          query: String.t(),
          provider: atom(),
          results: [SearchItem.t()],
          metadata: map(),
          raw: term()
        }

  defstruct query: "", provider: nil, results: [], metadata: %{}, raw: nil
end
