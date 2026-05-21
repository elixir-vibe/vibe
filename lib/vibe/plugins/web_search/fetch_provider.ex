defmodule Vibe.Plugins.WebSearch.FetchProvider do
  @moduledoc """
  Behaviour for URL fetch providers used by Vibe's `Web` eval API.

  Providers fetch a URL and return normalized `Vibe.Plugins.WebSearch.FetchResult` structs.
  Local providers may use `Req`; hosted deployments can swap in browser or page
  extraction services without changing agent-facing eval code.
  """

  alias Vibe.Plugins.WebSearch.FetchResult

  @callback fetch(String.t(), keyword()) :: {:ok, FetchResult.t()} | {:error, term()}
  @callback capabilities() :: map()

  @optional_callbacks capabilities: 0
end
