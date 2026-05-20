defmodule Vibe.Web.SessionsLive do
  @moduledoc "LiveView landing page for Vibe session history and active runtime status."
  use Vibe.Web, :live_view

  alias Vibe.Web.Sessions.Query

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibe.PubSub, Vibe.Session.sessions_topic())
    end

    {:ok, assign_dashboard(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     assign_sessions(
       socket,
       Map.get(params, "q", ""),
       Query.parse_page(Map.get(params, "page", "1"))
     )}
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:ok, session} = Vibe.Session.start()
    session_id = Vibe.Session.state(session).session_id
    {:noreply, push_navigate(socket, to: ~p"/sessions/#{session_id}")}
  end

  def handle_event("filter", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: sessions_path(query, 1))}
  end

  def handle_event("page", %{"page" => page}, socket) do
    {:noreply,
     push_patch(socket, to: sessions_path(socket.assigns.query, Query.parse_page(page)))}
  end

  def handle_event("select", %{"sessions" => selected}, socket) do
    {:noreply, assign(socket, :selected_sessions, MapSet.new(Map.keys(selected)))}
  end

  def handle_event("select", _params, socket) do
    {:noreply, assign(socket, :selected_sessions, MapSet.new())}
  end

  def handle_event("delete_selected", _params, socket) do
    result =
      socket.assigns.selected_sessions |> MapSet.to_list() |> Vibe.Session.Store.delete_many()

    {:noreply,
     socket
     |> put_flash(:info, delete_flash(result))
     |> assign(:selected_sessions, MapSet.new())
     |> assign_sessions(socket.assigns.query, socket.assigns.page)}
  end

  def handle_event("prune_empty", _params, socket) do
    pruned = Vibe.Session.Store.prune_empty()

    {:noreply,
     socket
     |> put_flash(:info, "Pruned #{length(pruned)} empty sessions.")
     |> assign_sessions(socket.assigns.query, socket.assigns.page)}
  end

  @impl true
  def handle_info({:session_changed, _session_id}, socket) do
    {:noreply, assign_sessions(socket, socket.assigns.query, socket.assigns.page)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:sessions} title="Agent sessions" subtitle="Attach to running work, reopen durable history, or start a fresh server-owned session.">
      <:actions>
        <button phx-click="new" class="inline-flex items-center gap-1.5 rounded-lg bg-vibe-accent px-3 py-2 text-sm font-semibold text-vibe-accent-contrast shadow-lg shadow-vibe-accent/20 transition-colors hover:bg-vibe-accent-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70 sm:px-4">
          <.icon name="lucide:plus" class="size-4" />
          <span>New session</span>
        </button>
      </:actions>

      <.sessions_toolbar
        filtered_count={@filtered_count}
        active_count={@active_count}
        message_total={@message_total}
        token_total={@token_total}
        query={@query}
        selected_count={MapSet.size(@selected_sessions)}
      />

      <.pagination page_start={@page_start} page_end={@page_end} filtered_count={@filtered_count} page={@page} total_pages={@total_pages} />

      <form phx-change="select" class="mt-6 space-y-6">
        <%= if @sessions == [] do %>
          <div class="rounded-xl border border-dashed border-vibe-border/60 p-10 text-center text-sm text-vibe-dim">No sessions matched.</div>
        <% else %>
          <.session_group title="Active" sessions={@session_groups.active} selected={@selected_sessions} />
          <.session_group title="Recent" sessions={@session_groups.recent} selected={@selected_sessions} />
          <.session_group title="Older" sessions={@session_groups.older} selected={@selected_sessions} />
        <% end %>
      </form>
    </.app_shell>
    """
  end

  defp assign_dashboard(socket) do
    socket
    |> assign(:active_count, Vibe.Session.active_count())
    |> assign(:selected_sessions, MapSet.new())
    |> assign_sessions("", 1)
  end

  defp assign_sessions(socket, query, page) do
    page_data = Query.page(query, page, @page_size)
    metrics = Query.metrics(page_data.filtered)

    selected =
      MapSet.intersection(
        socket.assigns.selected_sessions,
        MapSet.new(Enum.map(page_data.sessions, & &1.id))
      )

    socket
    |> assign(:query, page_data.query)
    |> assign(:sessions, page_data.sessions)
    |> assign(:session_groups, page_data.groups)
    |> assign(:selected_sessions, selected)
    |> assign(:filtered_count, length(page_data.filtered))
    |> assign(:page, page_data.page)
    |> assign(:total_pages, page_data.total_pages)
    |> assign(:page_start, page_data.page_start)
    |> assign(:page_end, page_data.page_end)
    |> assign(:message_total, metrics.message_total)
    |> assign(:token_total, metrics.token_total)
  end

  defp sessions_path(query, page) do
    query = String.trim(query || "")
    params = if query == "", do: %{page: page}, else: %{q: query, page: page}
    ~p"/?#{params}"
  end

  defp delete_flash(%{deleted: deleted, skipped: []}) do
    "Deleted #{length(deleted)} sessions."
  end

  defp delete_flash(%{deleted: deleted, skipped: skipped}) do
    "Deleted #{length(deleted)} sessions; skipped #{length(skipped)} live sessions."
  end
end
