defmodule Vibe.Web.StorageLive do
  @moduledoc "LiveView for SQLite-backed storage search and maintenance status."
  use Vibe.Web, :live_view

  @impl true
  def mount(params, _session, socket) do
    query = Map.get(params, "q", "")
    {:ok, assign_storage(socket, query)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign_storage(socket, query)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:storage} title="Storage" subtitle="Search sessions, memory, and indexed runtime history.">
      <section class="overflow-hidden rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/80">
        <div class="grid gap-px border-b border-vibe-border/50 bg-vibe-surface-muted sm:grid-cols-4">
          <.metric_tile label="Sessions" value={@session_count} />
          <.metric_tile label="Memory" value={@memory_count} />
          <.metric_tile label="UI events" value={table_count(@storage_status, "ui_events")} />
          <.metric_tile label="Artifacts" value={artifact_summary_text(@artifact_summary)} />
        </div>

        <form phx-submit="search" phx-change="search" class="flex flex-col gap-3 p-3 sm:flex-row sm:p-4">
          <label class="sr-only" for="storage-search">Search sessions and memory</label>
          <input id="storage-search" name="q" value={@query} autocomplete="off" placeholder="Search sessions, memories, snippets…" class="min-w-0 flex-1 rounded-lg border border-vibe-border/50 bg-vibe-bg px-3 py-2 text-sm text-vibe-fg-strong placeholder:text-vibe-dim focus:border-vibe-accent focus:outline-none focus:ring-2 focus:ring-vibe-accent/25" />
          <button class="rounded-lg bg-vibe-accent px-5 py-2 text-sm font-semibold text-vibe-accent-contrast transition-colors hover:bg-vibe-accent-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70 sm:w-auto">Search</button>
        </form>
      </section>

      <section class="mt-6 grid gap-3">
        <%= cond do %>
          <% @query == "" -> %>
            <div class="rounded-xl border border-dashed border-vibe-border/60 p-10 text-center text-sm leading-6 text-vibe-dim">
              <p>Search indexed sessions, UI events, and curated memory.</p>
              <p class="mt-2">Try <span class="font-mono text-vibe-muted">markdown</span>, <span class="font-mono text-vibe-muted">eval</span>, <span class="font-mono text-vibe-muted">storage</span>, or <span class="font-mono text-vibe-muted">session</span>.</p>
            </div>
          <% @error -> %>
            <div class="rounded-xl border border-vibe-error/30 bg-vibe-error/10 p-4 text-sm text-vibe-error">{inspect(@error)}</div>
          <% @results == [] -> %>
            <div class="rounded-xl border border-dashed border-vibe-border/60 p-10 text-center text-sm text-vibe-dim">No matches.</div>
          <% true -> %>
            <%= for result <- @results do %>
              <article class="rounded-xl border border-vibe-border/50 bg-vibe-surface/78 p-4">
                <div class="flex items-center justify-between gap-4">
                  <p class="text-xs uppercase tracking-[0.2em] text-vibe-accent">{result.source}</p>
                  <span class="text-xs text-vibe-dim">rank {Float.round(result.rank || 0.0, 3)}</span>
                </div>
                <p class="mt-3 break-words text-sm leading-6 text-vibe-fg [overflow-wrap:anywhere]">{Phoenix.HTML.raw(result.snippet || result.text || "")}</p>
                <div class="mt-3 flex flex-wrap gap-3 text-xs text-vibe-dim">
                  <.link :if={result.source == :session} navigate={~p"/sessions/#{result.owner_id}"} class="break-words font-mono text-vibe-accent-strong hover:text-vibe-accent-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70 [overflow-wrap:anywhere]">{result.owner_id}</.link>
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

  defp assign_storage(socket, query) do
    query = String.trim(query || "")

    {results, error} =
      case run_search(query) do
        {:ok, results} -> {results, nil}
        {:error, error} -> {[], error}
      end

    socket
    |> assign(:query, query)
    |> assign(:results, results)
    |> assign(:error, error)
    |> assign(:storage_status, Vibe.Storage.status())
    |> assign(:session_count, length(Vibe.Session.Store.list()))
    |> assign(:memory_count, memory_count())
    |> assign(:artifact_summary, artifact_summary())
  end

  defp run_search(""), do: {:ok, []}
  defp run_search(query), do: Vibe.Storage.Search.query(query, limit: 25)

  defp memory_count do
    length(Vibe.Memory.list(:global)) + length(Vibe.Memory.list(:user))
  end

  defp artifact_summary do
    Vibe.Session.Store.list()
    |> Enum.map(&Vibe.Files.Artifacts.session_artifact_summary(&1.id))
    |> Enum.reduce(%{count: 0, bytes: 0}, fn summary, acc ->
      %{count: acc.count + summary.count, bytes: acc.bytes + summary.bytes}
    end)
  end

  defp artifact_summary_text(%{count: count, bytes: bytes}),
    do: "#{count} / #{format_bytes(bytes)}"

  defp format_bytes(bytes) when bytes >= 1_000_000, do: "#{Float.round(bytes / 1_000_000, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1_000, do: "#{Float.round(bytes / 1_000, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"

  defp table_count(%{tables: tables}, table), do: Map.get(tables, table, 0)
  defp table_count(_status, _table), do: 0
end
