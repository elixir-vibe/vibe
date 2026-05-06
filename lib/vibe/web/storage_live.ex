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
      <section class="overflow-hidden rounded-xl border border-white/10 bg-[#141219]/80">
        <div class="grid gap-px border-b border-white/10 bg-white/10 sm:grid-cols-4">
          <.storage_metric label="Sessions" value={@session_count} />
          <.storage_metric label="Memory" value={@memory_count} />
          <.storage_metric label="UI events" value={table_count(@storage_status, "ui_events")} />
          <.storage_metric label="Artifacts" value={artifact_summary_text(@artifact_summary)} />
        </div>

        <form phx-submit="search" phx-change="search" class="flex flex-col gap-3 p-3 sm:flex-row sm:p-4">
          <label class="sr-only" for="storage-search">Search sessions and memory</label>
          <input id="storage-search" name="q" value={@query} autocomplete="off" placeholder="Search sessions, memories, snippets…" class="min-w-0 flex-1 rounded-lg border border-white/10 bg-[#0d0c11] px-3 py-2 text-sm text-zinc-100 placeholder:text-zinc-600 focus:border-violet-300 focus:outline-none focus:ring-2 focus:ring-violet-300/25" />
          <button class="rounded-lg bg-violet-400 px-5 py-2 text-sm font-semibold text-zinc-950 transition-colors hover:bg-violet-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-300/70 sm:w-auto">Search</button>
        </form>
      </section>

      <section class="mt-6 grid gap-3">
        <%= cond do %>
          <% @query == "" -> %>
            <div class="rounded-xl border border-dashed border-white/15 p-10 text-center text-sm leading-6 text-zinc-500">
              <p>Search indexed sessions, UI events, and curated memory.</p>
              <p class="mt-2">Try <span class="font-mono text-zinc-400">markdown</span>, <span class="font-mono text-zinc-400">eval</span>, <span class="font-mono text-zinc-400">storage</span>, or <span class="font-mono text-zinc-400">session</span>.</p>
            </div>
          <% @error -> %>
            <div class="rounded-xl border border-red-400/30 bg-red-400/10 p-4 text-sm text-red-100">{inspect(@error)}</div>
          <% @results == [] -> %>
            <div class="rounded-xl border border-dashed border-white/15 p-10 text-center text-sm text-zinc-500">No matches.</div>
          <% true -> %>
            <%= for result <- @results do %>
              <article class="rounded-xl border border-white/10 bg-[#17151d]/78 p-4">
                <div class="flex items-center justify-between gap-4">
                  <p class="text-xs uppercase tracking-[0.2em] text-violet-300">{result.source}</p>
                  <span class="text-xs text-zinc-500">rank {Float.round(result.rank || 0.0, 3)}</span>
                </div>
                <p class="mt-3 break-words text-sm leading-6 text-zinc-200 [overflow-wrap:anywhere]">{Phoenix.HTML.raw(result.snippet || result.text || "")}</p>
                <div class="mt-3 flex flex-wrap gap-3 text-xs text-zinc-500">
                  <.link :if={result.source == :session} navigate={~p"/sessions/#{result.owner_id}"} class="break-words font-mono text-orange-200 hover:text-orange-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70 [overflow-wrap:anywhere]">{result.owner_id}</.link>
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

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)

  def storage_metric(assigns) do
    ~H"""
    <div class="bg-[#141219] px-4 py-3">
      <p class="text-[0.65rem] font-medium uppercase tracking-[0.18em] text-zinc-600">{@label}</p>
      <p class="mt-1 font-mono text-xl text-zinc-100 tabular-nums">{@value}</p>
    </div>
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
