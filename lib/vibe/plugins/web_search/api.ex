defmodule Vibe.Plugins.WebSearch.API do
  @moduledoc """
  Backwards-compatible web API exposed by the WebSearch plugin.

  New code should treat this module as the eval alias target `Web` and use the
  provider-neutral functions `search/2` and `fetch/2`. Search and fetch providers
  can be swapped through Vibe config or per-call `:provider` options.
  """

  defdelegate search(query, opts \\ []), to: Vibe.WebTools
  defdelegate search!(query, opts \\ []), to: Vibe.WebTools
  defdelegate fetch(url, opts \\ []), to: Vibe.WebTools
  defdelegate fetch!(url, opts \\ []), to: Vibe.WebTools
  defdelegate filter_domain(search, domain), to: Vibe.WebTools
  defdelegate take(search, count), to: Vibe.WebTools
end
