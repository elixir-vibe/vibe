defmodule Vibe.Web.RuntimeLive do
  @moduledoc """
  LiveView runtime dashboard for Vibe's BEAM process.
  """
  use Vibe.Web, :live_view

  alias Vibe.OTP

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(2_000, :refresh)
    {:ok, assign_runtime(socket)}
  end

  @impl true
  def handle_info(:refresh, socket), do: {:noreply, assign_runtime(socket)}

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:runtime} title="Runtime" subtitle="Local Vibe server health, resource use, and background activity.">
      <section class="grid gap-4 sm:grid-cols-2 xl:grid-cols-[minmax(0,1.25fr)_repeat(3,minmax(0,1fr))]">
        <.panel title="Node">
          <div class="space-y-3 text-sm text-vibe-fg">
            <div class="flex justify-between"><span class="text-vibe-dim">OTP</span><span>{@runtime.otp_release}</span></div>
            <div class="flex justify-between"><span class="text-vibe-dim">Elixir</span><span>{@runtime.elixir}</span></div>
            <div class="flex justify-between"><span class="text-vibe-dim">Schedulers</span><span>{@runtime.schedulers}</span></div>
            <div class="flex justify-between"><span class="text-vibe-dim">Active sessions</span><span>{@active_count}</span></div>
          </div>
        </.panel>

        <.stat_card label="Processes" value={@runtime.process_count} />
        <.stat_card label="ETS tables" value={length(@ets)} accent="text-vibe-accent" />
        <.stat_card label="Memory MB" value={memory_mb(@runtime.memory[:total])} accent="text-cyan-300" />
      </section>

      <section class="mt-6 grid gap-6 xl:grid-cols-2">
        <.panel title="Top processes by memory">
          <div class="overflow-x-auto">
            <table class="min-w-[34rem] text-left text-xs text-vibe-muted">
              <thead class="text-[0.65rem] uppercase tracking-[0.18em] text-vibe-dim"><tr><th class="py-2">#</th><th>PID</th><th>Name</th><th>Memory</th><th>Queue</th></tr></thead>
              <tbody class="divide-y divide-white/5">
                <tr :for={process <- @top}>
                  <td class="py-2 text-vibe-dim">{process.index}</td>
                  <td class="font-mono text-vibe-fg">{process.pid}</td>
                  <td>{inspect(process.name || process.initial_call)}</td>
                  <td>{process.memory}</td>
                  <td>{process.message_queue_len}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </.panel>

        <.panel title="Largest ETS tables">
          <div class="overflow-x-auto">
            <table class="min-w-[28rem] text-left text-xs text-vibe-muted">
              <thead class="text-[0.65rem] uppercase tracking-[0.18em] text-vibe-dim"><tr><th class="py-2">Name</th><th>Size</th><th>Memory</th></tr></thead>
              <tbody class="divide-y divide-white/5">
                <tr :for={table <- @ets}>
                  <td class="py-2 font-mono text-vibe-fg">{inspect(table.name || table.id)}</td>
                  <td>{table.size}</td>
                  <td>{table.memory}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </.panel>
      </section>
    </.app_shell>
    """
  end

  defp assign_runtime(socket) do
    socket
    |> assign(:runtime, OTP.runtime_info())
    |> assign(:top, OTP.top(:memory, limit: 12))
    |> assign(:ets, OTP.ets_tables(limit: 12))
    |> assign(:active_count, Vibe.Session.active_count())
  end

  defp memory_mb(nil), do: 0
  defp memory_mb(bytes), do: Float.round(bytes / 1_048_576, 1)
end
