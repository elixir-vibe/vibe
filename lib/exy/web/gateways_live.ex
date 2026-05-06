defmodule Exy.Web.GatewaysLive do
  @moduledoc """
  LiveView dashboard for external gateway runtimes and sessions.
  """
  use Exy.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(2_000, :refresh)
    {:ok, assign_gateways(socket)}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, assign_gateways(socket)}

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:gateways} title="Gateways" subtitle="External chat gateway runtimes, delivery counters, and topic-backed Exy sessions.">
      <:sidebar>
        <.panel title="Status">
          <div class="space-y-3 text-sm text-zinc-300">
            <div class="flex justify-between"><span class="text-zinc-500">Configured</span><span>{length(@statuses)}</span></div>
            <div class="flex justify-between"><span class="text-zinc-500">Running</span><span>{Enum.count(@statuses, &(&1.status == :running))}</span></div>
            <div class="flex justify-between"><span class="text-zinc-500">Gateway sessions</span><span>{length(@sessions)}</span></div>
          </div>
        </.panel>
      </:sidebar>

      <section class="space-y-4">
        <.panel title="Gateway runtimes">
          <div class="overflow-x-auto">
            <table class="min-w-[42rem] text-left text-xs text-zinc-400">
              <thead class="text-[0.65rem] uppercase tracking-[0.18em] text-zinc-500">
                <tr><th class="py-2">Gateway</th><th>Backend</th><th>Status</th><th>Accepted</th><th>Rejected</th><th>Ignored</th><th>Failed</th><th>PID</th></tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <tr :for={gateway <- @statuses}>
                  <td class="py-2 font-mono text-zinc-200">{gateway.id}</td>
                  <td class="font-mono">{inspect(gateway.backend)}</td>
                  <td><.gateway_status_badge status={gateway.status} /></td>
                  <td>{gateway.stats.accepted}</td>
                  <td>{gateway.stats.rejected}</td>
                  <td>{gateway.stats.ignored}</td>
                  <td>{gateway.stats.failed}</td>
                  <td class="font-mono text-zinc-500">{gateway.pid || "-"}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </.panel>

        <.panel title="Recent gateway sessions">
          <div class="overflow-x-auto">
            <table class="min-w-[48rem] text-left text-xs text-zinc-400">
              <thead class="text-[0.65rem] uppercase tracking-[0.18em] text-zinc-500">
                <tr><th class="py-2">Session</th><th>Platform</th><th>Chat</th><th>Thread / topic</th><th>User</th><th>Messages</th><th>Updated</th></tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <tr :for={session <- @sessions}>
                  <td class="max-w-[18rem] truncate py-2 font-mono text-zinc-200">
                    <.link navigate={~p"/sessions/#{session.id}"} class="hover:text-orange-300">{session.id}</.link>
                  </td>
                  <td>{session.gateway_source[:platform] || "-"}</td>
                  <td class="font-mono">{session.gateway_source[:chat_id] || "-"}</td>
                  <td class="font-mono text-orange-200">{session.gateway_source[:thread_id] || "-"}</td>
                  <td class="font-mono">{session.gateway_source[:user_id] || "-"}</td>
                  <td>{session.message_count}</td>
                  <td>{format_time(session.updated_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </.panel>
      </section>
    </.app_shell>
    """
  end

  attr(:status, :atom, required: true)

  defp gateway_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex rounded-full px-2 py-1 text-[0.65rem] font-semibold uppercase tracking-[0.16em]",
      case @status do
        :running -> "bg-emerald-400/10 text-emerald-300"
        :stopped -> "bg-yellow-400/10 text-yellow-300"
        _ -> "bg-zinc-400/10 text-zinc-400"
      end
    ]}>{@status}</span>
    """
  end

  defp assign_gateways(socket) do
    socket
    |> assign(:statuses, Exy.Gateway.statuses())
    |> assign(:sessions, Exy.Gateway.sessions(limit: 30))
  end

  defp format_time(nil), do: "-"
  defp format_time(%DateTime{} = time), do: Calendar.strftime(time, "%Y-%m-%d %H:%M:%S")
end
