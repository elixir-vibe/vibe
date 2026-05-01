defmodule Exy.Web.SessionsLive do
  @moduledoc """
  LiveView landing page for Exy session history and active runtime status.
  """
  use Exy.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_dashboard(socket)}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:ok, session} = Exy.Session.start()
    session_id = Exy.Session.state(session).session_id
    {:noreply, push_navigate(socket, to: ~p"/sessions/#{session_id}")}
  end

  @impl true
  def handle_event("filter", %{"q" => query}, socket) do
    {:noreply, socket |> assign(query: query) |> assign(:sessions, sessions(query))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:sessions} title="Agent sessions" subtitle="Attach to running work, reopen durable history, or start a fresh server-owned session.">
      <:actions>
        <button phx-click="new" class="rounded-xl bg-orange-400 px-4 py-2 text-sm font-semibold text-zinc-950 shadow-lg shadow-orange-950/30 transition hover:bg-orange-300">
          New session
        </button>
      </:actions>

      <:sidebar>
        <.panel title="Runtime snapshot">
          <div class="space-y-3 text-sm text-zinc-300">
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Active</span><span>{@active_count}</span></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Processes</span><span>{@runtime.process_count}</span></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Schedulers</span><span>{@runtime.schedulers}</span></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Elixir</span><span>{@runtime.elixir}</span></div>
            <.link navigate={~p"/runtime"} class="mt-3 block rounded-lg border border-white/10 px-3 py-2 text-center text-xs text-zinc-300 hover:border-orange-300/50 hover:text-orange-100">Open runtime</.link>
          </div>
        </.panel>
      </:sidebar>

      <:inspector>
        <.panel title="What the web UI exposes">
          <ul class="space-y-2 text-sm leading-6 text-zinc-400">
            <li>• semantic session history</li>
            <li>• live transcript and composer</li>
            <li>• storage-backed search</li>
            <li>• BEAM/runtime inspection</li>
            <li>• TUI-equivalent state rendered as LiveView</li>
          </ul>
        </.panel>
      </:inspector>

      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <.stat_card label="Sessions" value={length(@sessions)} />
        <.stat_card label="Active" value={@active_count} accent="text-emerald-300" />
        <.stat_card label="Messages" value={@message_total} accent="text-violet-300" />
        <.stat_card label="Tokens" value={@token_total} accent="text-cyan-300" />
      </div>

      <form phx-change="filter" class="mt-6">
        <label class="sr-only" for="session-search">Search sessions</label>
        <input id="session-search" name="q" value={@query} placeholder="Filter sessions by prompt, cwd, model, or id..." class="w-full rounded-2xl border border-white/10 bg-zinc-900/80 px-4 py-3 text-sm text-zinc-100 outline-none ring-orange-300/20 placeholder:text-zinc-600 focus:border-orange-300 focus:ring-4" />
      </form>

      <section class="mt-6 grid gap-3">
        <%= if @sessions == [] do %>
          <div class="rounded-2xl border border-dashed border-white/15 p-10 text-center text-sm text-zinc-500">No sessions matched.</div>
        <% else %>
          <%= for session <- @sessions do %>
            <.session_card session={session} />
          <% end %>
        <% end %>
      </section>
    </.app_shell>
    """
  end

  defp assign_dashboard(socket) do
    sessions = sessions("")
    usage = Enum.map(sessions, &(&1.usage || %{}))

    socket
    |> assign(:query, "")
    |> assign(:sessions, sessions)
    |> assign(:active_count, Exy.Session.active_count())
    |> assign(:runtime, Exy.OTP.runtime_info())
    |> assign(:message_total, Enum.sum(Enum.map(sessions, &(&1.message_count || 0))))
    |> assign(:token_total, Enum.sum(Enum.map(usage, &Map.get(&1, :total_tokens, 0))))
  end

  defp sessions(query) do
    query = String.downcase(String.trim(query || ""))

    Exy.Session.Store.list()
    |> Enum.take(80)
    |> Enum.filter(fn session -> query == "" or session_matches?(session, query) end)
  end

  defp session_matches?(session, query) do
    [
      session.id,
      session.cwd,
      session.first_message,
      session.last_message_preview,
      session.model,
      session.status
    ]
    |> Enum.map(&to_string/1)
    |> Enum.any?(&(String.downcase(&1) =~ query))
  end
end
