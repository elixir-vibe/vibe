defmodule Vibe.Web.Sessions.Components do
  @moduledoc "Components specific to the sessions index page."
  use Phoenix.Component

  import PhoenixIconify, only: [icon: 1]
  import Vibe.Web.Components.Core, only: [metric_tile: 1]

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
    <section class="overflow-hidden rounded-t-xl border border-vibe-border/50 bg-vibe-bg-soft/80">
      <div class="grid gap-px border-b border-vibe-border/50 bg-vibe-surface-muted sm:grid-cols-4">
        <.metric_tile label="Sessions" value={@filtered_count} />
        <.metric_tile label="Live" value={@active_count} />
        <.metric_tile label="Messages" value={@message_total} />
        <.metric_tile label="Tokens" value={@token_total} />
      </div>

      <div class="flex flex-col gap-3 p-3 sm:flex-row sm:items-center sm:justify-between sm:p-4">
        <form phx-change="filter" class="min-w-0 flex-1">
          <label class="sr-only" for="session-search">Search sessions</label>
          <div class="relative">
            <.icon name="lucide:search" class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-vibe-dim" />
            <input id="session-search" name="q" value={@query} autocomplete="off" placeholder="Search prompt, workspace, model, or id…" class="w-full rounded-lg border border-vibe-border/50 bg-vibe-bg py-2 pl-9 pr-3 text-sm text-vibe-fg-strong placeholder:text-vibe-dim focus:border-vibe-accent focus:outline-none focus:ring-2 focus:ring-vibe-accent/25" />
          </div>
        </form>

        <div class="flex shrink-0 flex-wrap items-center gap-2 text-xs">
          <button type="button" phx-click="prune_empty" class="rounded-md border border-vibe-border/50 px-2.5 py-2 text-vibe-muted hover:border-vibe-border hover:text-vibe-fg-strong">Prune Empty</button>
          <button type="button" phx-click="delete_selected" disabled={@selected_count == 0} class="rounded-md border border-vibe-error/20 px-2.5 py-2 text-vibe-error disabled:cursor-not-allowed disabled:opacity-35 hover:border-vibe-error/50">Delete {@selected_count}</button>
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
    <div class="mt-0 flex flex-col gap-3 rounded-b-xl border-x border-b border-vibe-border/50 bg-vibe-bg-soft/80 px-3 py-3 text-sm text-vibe-dim sm:flex-row sm:items-center sm:justify-between sm:px-4">
      <p>
        Showing <span class="font-mono text-vibe-fg">{@page_start}</span>–<span class="font-mono text-vibe-fg">{@page_end}</span> of <span class="font-mono text-vibe-fg">{@filtered_count}</span>
      </p>
      <div class="flex items-center gap-2">
        <button type="button" phx-click="page" phx-value-page={@page - 1} disabled={@page <= 1} class="rounded-md border border-vibe-border/50 px-2.5 py-2 text-xs text-vibe-fg disabled:cursor-not-allowed disabled:opacity-35 hover:border-vibe-border">Previous</button>
        <span class="min-w-16 text-center text-xs tabular-nums text-vibe-dim">{@page} / {@total_pages}</span>
        <button type="button" phx-click="page" phx-value-page={@page + 1} disabled={@page >= @total_pages} class="rounded-md border border-vibe-border/50 px-2.5 py-2 text-xs text-vibe-fg disabled:cursor-not-allowed disabled:opacity-35 hover:border-vibe-border">Next</button>
      </div>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:sessions, :list, required: true)
  attr(:selected, MapSet, required: true)

  def session_group(assigns) do
    ~H"""
    <section :if={@sessions != []} class="overflow-hidden rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/72">
      <header class="border-b border-vibe-border/50 px-3 py-2 sm:px-4">
        <h2 class="text-xs font-semibold uppercase tracking-[0.22em] text-vibe-dim">{@title}</h2>
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
    <div class="grid grid-cols-[1.75rem_minmax(0,1fr)] items-start gap-2 px-3 py-3 hover:bg-vibe-surface-muted/35 sm:grid-cols-[1.75rem_minmax(0,1fr)_auto] sm:px-4">
      <label class="pt-1">
        <input type="checkbox" name={"sessions[#{@session.id}]"} checked={MapSet.member?(@selected, @session.id)} disabled={Map.get(@session, :live?, false)} class="size-4 rounded border-vibe-border/70 bg-vibe-bg text-vibe-accent disabled:cursor-not-allowed disabled:opacity-30" />
        <span class="sr-only">Select {@session.id}</span>
      </label>

      <.link navigate={~p"/sessions/#{@session.id}"} class="min-w-0 rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70">
        <p class="truncate text-sm font-medium text-vibe-fg-strong hover:text-vibe-accent-strong">{Query.session_title(@session)}</p>
        <p class="mt-1 truncate font-mono text-xs text-vibe-dim">{Map.get(@session, :cwd) || "unknown workspace"}</p>
        <div class="mt-2 flex min-w-0 flex-wrap gap-x-3 gap-y-1 text-xs text-vibe-dim">
          <span class="font-mono">{@session.id}</span>
          <span>{Map.get(@session, :message_count, 0)} messages</span>
          <span :if={Map.get(@session, :model)}>{Map.get(@session, :model)}</span>
          <span :if={Map.get(@session, :remote?)} class="rounded bg-vibe-accent/15 px-1.5 py-0.5 text-vibe-accent">remote</span>
        </div>
      </.link>

      <div class="col-start-2 sm:col-start-auto sm:pt-0.5">
        <Vibe.Web.Components.Core.status_badge status={Map.get(@session, :status, :idle)} />
      </div>
    </div>
    """
  end
end
