defmodule Vibe.WebTools.SearchProvider do
  @moduledoc """
  Behaviour for web search providers used by Vibe's `Web` eval API.

  Providers translate a common Vibe search request into vendor-specific APIs and
  return normalized `Vibe.WebTools.SearchResult` structs. Provider-specific data
  belongs in result metadata so callers can keep using the same eval API when the
  configured search backend changes.
  """

  alias Vibe.WebTools.SearchResult

  @callback search(String.t(), keyword()) :: {:ok, SearchResult.t()} | {:error, term()}
  @callback capabilities() :: map()

  @optional_callbacks capabilities: 0
end
