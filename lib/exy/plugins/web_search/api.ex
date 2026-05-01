defmodule Exy.Plugins.WebSearch.API do
  @moduledoc """
  Backwards-compatible web API exposed by the WebSearch plugin.

  New code should treat this module as the eval alias target `Web` and use the
  provider-neutral functions `search/2` and `fetch/2`. Search and fetch providers
  can be swapped through Exy config or per-call `:provider` options.
  """

  defdelegate search(query, opts \\ []), to: Exy.WebTools
  defdelegate search!(query, opts \\ []), to: Exy.WebTools
  defdelegate fetch(url, opts \\ []), to: Exy.WebTools
  defdelegate fetch!(url, opts \\ []), to: Exy.WebTools
  defdelegate filter_domain(search, domain), to: Exy.WebTools
  defdelegate take(search, count), to: Exy.WebTools
end
