defmodule Vibe.Plugins.WebSearch.API do
  @moduledoc """
  Backwards-compatible web API exposed by the WebSearch plugin.

  New code should treat this module as the eval alias target `Web` and use the
  provider-neutral functions `search/2` and `fetch/2`. Search and fetch providers
  can be swapped through Vibe config or per-call `:provider` options.
  """

  @doc "Intentional facade for the public Vibe API boundary."
  defdelegate search(query, opts \\ []), to: Vibe.WebTools
  @doc "Intentional facade for the public Vibe API boundary."
  defdelegate search!(query, opts \\ []), to: Vibe.WebTools
  @doc "Intentional facade for the public Vibe API boundary."
  defdelegate fetch(url, opts \\ []), to: Vibe.WebTools
  @doc "Intentional facade for the public Vibe API boundary."
  defdelegate fetch!(url, opts \\ []), to: Vibe.WebTools
  @doc "Intentional facade for the public Vibe API boundary."
  defdelegate filter_domain(search, domain), to: Vibe.WebTools
  @doc "Intentional facade for the public Vibe API boundary."
  defdelegate take(search, count), to: Vibe.WebTools
end
