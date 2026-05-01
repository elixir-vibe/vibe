defmodule Exy.Web.SearchLive do
  @moduledoc """
  LiveView for storage-backed search across Exy sessions and memory.
  """
  use Exy.Web, :live_view

  @impl true
  def mount(params, _session, socket) do
    query = Map.get(params, "q", "")
    {:ok, assign_search(socket, query)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign_search(socket, query)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:search} title="Search" subtitle="Search durable sessions and curated memory through Exy's SQLite FTS indexes.">
      <:sidebar>
        <.panel title="Scopes">
          <p class="text-sm leading-6 text-zinc-400">Search currently includes user/assistant session text and curated memory. Tool output can be added as a filter.</p>
        </.panel>
      </:sidebar>

      <form phx-submit="search" phx-change="search" class="flex gap-3 rounded-3xl border border-white/10 bg-zinc-900/70 p-3">
        <input name="q" value={@query} placeholder="Search sessions, memories, snippets..." class="min-w-0 flex-1 rounded-2xl border border-white/10 bg-zinc-950/80 px-4 py-3 text-sm text-zinc-100 outline-none ring-violet-300/20 placeholder:text-zinc-600 focus:border-violet-300 focus:ring-4" />
        <button class="rounded-2xl bg-violet-400 px-5 py-3 text-sm font-semibold text-zinc-950 hover:bg-violet-300">Search</button>
      </form>

      <section class="mt-6 grid gap-3">
        <%= cond do %>
          <% @query == "" -> %>
            <div class="rounded-2xl border border-dashed border-white/15 p-10 text-center text-sm text-zinc-500">Enter a query to search Exy history.</div>
          <% @error -> %>
            <div class="rounded-2xl border border-red-400/30 bg-red-400/10 p-4 text-sm text-red-100">{inspect(@error)}</div>
          <% @results == [] -> %>
            <div class="rounded-2xl border border-dashed border-white/15 p-10 text-center text-sm text-zinc-500">No matches.</div>
          <% true -> %>
            <%= for result <- @results do %>
              <article class="rounded-2xl border border-white/10 bg-zinc-900/70 p-4">
                <div class="flex items-center justify-between gap-4">
                  <p class="text-xs uppercase tracking-[0.2em] text-violet-300">{result.source}</p>
                  <span class="text-xs text-zinc-500">rank {Float.round(result.rank || 0.0, 3)}</span>
                </div>
                <p class="mt-3 text-sm leading-6 text-zinc-200">{Phoenix.HTML.raw(result.snippet || result.text || "")}</p>
                <div class="mt-3 flex flex-wrap gap-3 text-xs text-zinc-500">
                  <.link :if={result.source == :session} navigate={~p"/sessions/#{result.owner_id}"} class="font-mono text-orange-200 hover:text-orange-100">{result.owner_id}</.link>
                  <span :if={result.source == :memory}>{result.owner_id}</span>
                  <span :if={result.at}>{result.at}</span>
                </div>
              </article>
            <% end %>
        <% end %>
      </section>
    </.app_shell>
    """
  end

  defp assign_search(socket, query) do
    query = String.trim(query || "")

    case run_search(query) do
      {:ok, results} -> assign(socket, query: query, results: results, error: nil)
      {:error, error} -> assign(socket, query: query, results: [], error: error)
    end
  end

  defp run_search(""), do: {:ok, []}
  defp run_search(query), do: Exy.Storage.Search.query(query, limit: 25)
end
