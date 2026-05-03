defmodule Exy.WebTools.SearchProvider do
  @moduledoc """
  Behaviour for web search providers used by Exy's `Web` eval API.

  Providers translate a common Exy search request into vendor-specific APIs and
  return normalized `Exy.WebTools.SearchResult` structs. Provider-specific data
  belongs in result metadata so callers can keep using the same eval API when the
  configured search backend changes.
  """

  alias Exy.WebTools.SearchResult

  @callback search(String.t(), keyword()) :: {:ok, SearchResult.t()} | {:error, term()}
  @callback capabilities() :: map()

  @optional_callbacks capabilities: 0
end
