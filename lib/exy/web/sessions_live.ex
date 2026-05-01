defmodule Exy.Web.SessionsLive do
  @moduledoc "Internal implementation module."
  use Exy.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, sessions: sessions(), active_count: Exy.Session.active_count())}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:ok, session} = Exy.Session.start()
    session_id = Exy.Session.state(session).session_id
    {:noreply, push_navigate(socket, to: ~p"/sessions/#{session_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-8 px-6 py-8">
      <header class="flex items-center justify-between">
        <div>
          <p class="text-sm uppercase tracking-[0.3em] text-cyan-300/80">Exy Web</p>
          <h1 class="mt-2 text-3xl font-semibold tracking-tight">Agent sessions</h1>
          <p class="mt-2 text-sm text-zinc-400">{@active_count} active process(es), SQLite-backed history, LiveView client.</p>
        </div>
        <button phx-click="new" class="rounded-xl bg-cyan-400 px-4 py-2 text-sm font-semibold text-zinc-950 shadow-lg shadow-cyan-950/40 hover:bg-cyan-300">
          New session
        </button>
      </header>

      <section class="grid gap-3">
        <%= for session <- @sessions do %>
          <.link navigate={~p"/sessions/#{session.id}"} class="group rounded-2xl border border-zinc-800 bg-zinc-900/70 p-4 transition hover:border-cyan-400/70 hover:bg-zinc-900">
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0">
                <p class="truncate text-sm font-medium text-zinc-100">{session.first_message || Map.get(session, :title) || "Untitled session"}</p>
                <p class="mt-1 truncate text-xs text-zinc-500">{session.cwd || "unknown cwd"}</p>
              </div>
              <span class="rounded-full bg-zinc-800 px-2 py-1 text-xs text-zinc-400 group-hover:text-cyan-200">{session.status}</span>
            </div>
            <div class="mt-3 flex items-center gap-3 text-xs text-zinc-500">
              <span class="font-mono">{session.id}</span>
              <span>{session.message_count || 0} messages</span>
            </div>
          </.link>
        <% end %>
      </section>
    </main>
    """
  end

  defp sessions do
    Exy.Session.Store.list()
    |> Enum.take(50)
  end
end
