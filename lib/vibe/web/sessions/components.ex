defmodule Vibe.Web.Sessions.Components do
  @moduledoc "Components specific to the sessions index page."
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: Vibe.Web.Endpoint,
    router: Vibe.Web.Router,
    statics: Vibe.Web.static_paths()

  alias Vibe.Web.Sessions.Query

  attr(:filtered_count, :integer, required: true)
  attr(:active_count, :integer, required: true)
  attr(:message_total, :integer, required: true)
  attr(:token_total, :integer, required: true)
  attr(:query, :string, required: true)
  attr(:selected_count, :integer, required: true)

  def sessions_toolbar(assigns) do
    ~H"""
    <section class="overflow-hidden rounded-t-xl border border-white/10 bg-[#141219]/80">
      <div class="grid gap-px border-b border-white/10 bg-white/10 sm:grid-cols-4">
        <.metric label="Sessions" value={@filtered_count} />
        <.metric label="Live" value={@active_count} />
        <.metric label="Messages" value={@message_total} />
        <.metric label="Tokens" value={@token_total} />
      </div>

      <div class="flex flex-col gap-3 p-3 sm:flex-row sm:items-center sm:justify-between sm:p-4">
        <form phx-change="filter" class="min-w-0 flex-1">
          <label class="sr-only" for="session-search">Search sessions</label>
          <input id="session-search" name="q" value={@query} autocomplete="off" placeholder="Search prompt, workspace, model, or id…" class="w-full rounded-lg border border-white/10 bg-[#0d0c11] px-3 py-2 text-sm text-zinc-100 placeholder:text-zinc-600 focus:border-orange-300 focus:outline-none focus:ring-2 focus:ring-orange-300/25" />
        </form>

        <div class="flex shrink-0 flex-wrap items-center gap-2 text-xs">
          <button type="button" phx-click="prune_empty" class="rounded-md border border-white/10 px-2.5 py-2 text-zinc-400 hover:border-white/20 hover:text-zinc-100">Prune Empty</button>
          <button type="button" phx-click="delete_selected" disabled={@selected_count == 0} class="rounded-md border border-red-300/20 px-2.5 py-2 text-red-200 disabled:cursor-not-allowed disabled:opacity-35 hover:border-red-300/50">Delete {@selected_count}</button>
        </div>
      </div>
    </section>
    """
  end

  attr(:page_start, :integer, required: true)
  attr(:page_end, :integer, required: true)
  attr(:filtered_count, :integer, required: true)
  attr(:page, :integer, required: true)
  attr(:total_pages, :integer, required: true)

  def pagination(assigns) do
    ~H"""
    <div class="mt-0 flex flex-col gap-3 rounded-b-xl border-x border-b border-white/10 bg-[#141219]/80 px-3 py-3 text-sm text-zinc-500 sm:flex-row sm:items-center sm:justify-between sm:px-4">
      <p>
        Showing <span class="font-mono text-zinc-200">{@page_start}</span>–<span class="font-mono text-zinc-200">{@page_end}</span> of <span class="font-mono text-zinc-200">{@filtered_count}</span>
      </p>
      <div class="flex items-center gap-2">
        <button type="button" phx-click="page" phx-value-page={@page - 1} disabled={@page <= 1} class="rounded-md border border-white/10 px-2.5 py-2 text-xs text-zinc-300 disabled:cursor-not-allowed disabled:opacity-35 hover:border-white/20">Previous</button>
        <span class="min-w-16 text-center text-xs tabular-nums text-zinc-500">{@page} / {@total_pages}</span>
        <button type="button" phx-click="page" phx-value-page={@page + 1} disabled={@page >= @total_pages} class="rounded-md border border-white/10 px-2.5 py-2 text-xs text-zinc-300 disabled:cursor-not-allowed disabled:opacity-35 hover:border-white/20">Next</button>
      </div>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:sessions, :list, required: true)
  attr(:selected, MapSet, required: true)

  def session_group(assigns) do
    ~H"""
    <section :if={@sessions != []} class="overflow-hidden rounded-xl border border-white/10 bg-[#141219]/72">
      <header class="border-b border-white/10 px-3 py-2 sm:px-4">
        <h2 class="text-xs font-semibold uppercase tracking-[0.22em] text-zinc-500">{@title}</h2>
      </header>
      <div class="divide-y divide-white/8">
        <%= for session <- @sessions do %>
          <.session_row session={session} selected={@selected} />
        <% end %>
      </div>
    </section>
    """
  end

  attr(:session, :map, required: true)
  attr(:selected, MapSet, required: true)

  def session_row(assigns) do
    ~H"""
    <div class="grid grid-cols-[1.75rem_minmax(0,1fr)] items-start gap-2 px-3 py-3 hover:bg-white/[0.025] sm:grid-cols-[1.75rem_minmax(0,1fr)_auto] sm:px-4">
      <label class="pt-1">
        <input type="checkbox" name={"sessions[#{@session.id}]"} checked={MapSet.member?(@selected, @session.id)} disabled={Map.get(@session, :live?, false)} class="size-4 rounded border-white/20 bg-[#0d0c11] text-orange-400 disabled:cursor-not-allowed disabled:opacity-30" />
        <span class="sr-only">Select {@session.id}</span>
      </label>

      <.link navigate={~p"/sessions/#{@session.id}"} class="min-w-0 rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">
        <p class="truncate text-sm font-medium text-zinc-100 hover:text-orange-100">{Query.session_title(@session)}</p>
        <p class="mt-1 truncate font-mono text-xs text-zinc-500">{Map.get(@session, :cwd) || "unknown workspace"}</p>
        <div class="mt-2 flex min-w-0 flex-wrap gap-x-3 gap-y-1 text-xs text-zinc-600">
          <span class="font-mono">{@session.id}</span>
          <span>{Map.get(@session, :message_count, 0)} messages</span>
          <span :if={Map.get(@session, :model)}>{Map.get(@session, :model)}</span>
        </div>
      </.link>

      <div class="col-start-2 sm:col-start-auto sm:pt-0.5">
        <Vibe.Web.Components.Core.status_badge status={Map.get(@session, :status, :idle)} />
      </div>
    </div>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)

  def metric(assigns) do
    ~H"""
    <div class="bg-[#141219] px-4 py-3">
      <p class="text-[0.65rem] font-medium uppercase tracking-[0.18em] text-zinc-600">{@label}</p>
      <p class="mt-1 font-mono text-xl text-zinc-100 tabular-nums">{@value}</p>
    </div>
    """
  end
end
