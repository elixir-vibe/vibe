defmodule Vibe.Web.SearchLive do
  @moduledoc "Compatibility route for the former `/search` page."
  use Vibe.Web, :live_view

  @impl true
  def mount(params, _session, socket) do
    {:ok, push_navigate(socket, to: storage_path(params))}
  end

  defp storage_path(params) do
    case Map.get(params, "q") do
      nil -> ~p"/storage"
      "" -> ~p"/storage"
      query -> ~p"/storage?#{%{q: query}}"
    end
  end
end
