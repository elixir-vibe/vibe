defmodule Exy.WebTools.FetchProvider do
  @moduledoc """
  Behaviour for URL fetch providers used by Exy's `Web` eval API.

  Providers fetch a URL and return normalized `Exy.WebTools.FetchResult` structs.
  Local providers may use `Req`; hosted deployments can swap in browser or page
  extraction services without changing agent-facing eval code.
  """

  @callback fetch(String.t(), keyword()) :: {:ok, Exy.WebTools.FetchResult.t()} | {:error, term()}
  @callback capabilities() :: map()

  @optional_callbacks capabilities: 0
end
