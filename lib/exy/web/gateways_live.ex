defmodule Exy.Web.GatewaysLive do
  @moduledoc """
  LiveView dashboard for external gateway runtimes and sessions.
  """
  use Exy.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(2_000, :refresh)

    socket =
      socket
      |> assign(:telegram_info, telegram_info())
      |> assign(:telegram_polling, Exy.Gateway.Telegram.polling_status())
      |> assign_gateways()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:telegram_polling, Exy.Gateway.Telegram.polling_status())
     |> assign_gateways()}
  end

  @impl true
  def handle_event("telegram_get_me", _params, socket),
    do: {:noreply, run_telegram_action(socket, :get_me)}

  def handle_event("telegram_webhook", _params, socket),
    do: {:noreply, run_telegram_action(socket, :webhook)}

  def handle_event("telegram_updates", _params, socket),
    do: {:noreply, run_telegram_action(socket, :updates)}

  def handle_event("telegram_start", _params, socket) do
    result = Exy.Gateway.Telegram.start_polling()

    {:noreply,
     socket
     |> put_action_result(:telegram_start, result)
     |> assign(:telegram_polling, Exy.Gateway.Telegram.polling_status())
     |> assign_gateways()}
  end

  def handle_event("telegram_stop", _params, socket) do
    result = Exy.Gateway.Telegram.stop_polling()

    {:noreply,
     socket
     |> put_action_result(:telegram_stop, result)
     |> assign(:telegram_polling, Exy.Gateway.Telegram.polling_status())
     |> assign_gateways()}
  end

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
        <.panel title="Telegram status">
          <div class="grid gap-3 text-sm text-zinc-300 sm:grid-cols-2">
            <div class="rounded-xl border border-white/10 bg-white/[0.03] p-3">
              <div class="text-[0.65rem] uppercase tracking-[0.18em] text-zinc-500">Bot</div>
              <div class="mt-2 font-medium text-zinc-100">{telegram_bot_label(@telegram_info.get_me)}</div>
              <div class="mt-1 font-mono text-xs text-zinc-500">{telegram_bot_detail(@telegram_info.get_me)}</div>
            </div>
            <div class="rounded-xl border border-white/10 bg-white/[0.03] p-3">
              <div class="text-[0.65rem] uppercase tracking-[0.18em] text-zinc-500">Webhook</div>
              <div class="mt-2 font-medium text-zinc-100">{telegram_webhook_label(@telegram_info.webhook)}</div>
              <div class="mt-1 break-all font-mono text-xs text-zinc-500">{telegram_webhook_detail(@telegram_info.webhook)}</div>
            </div>
          </div>
        </.panel>

        <.panel title="Telegram polling diagnostics">
          <div class="grid gap-3 text-xs text-zinc-400 sm:grid-cols-3">
            <div class="rounded-xl border border-white/10 bg-white/[0.03] p-3">
              <div class="text-[0.65rem] uppercase tracking-[0.18em] text-zinc-500">State</div>
              <div class="mt-2 font-medium text-zinc-100">{polling_state_label(@telegram_polling)}</div>
              <div class="mt-1 font-mono text-zinc-500">offset {polling_value(@telegram_polling, :offset)}</div>
            </div>
            <div class="rounded-xl border border-white/10 bg-white/[0.03] p-3">
              <div class="text-[0.65rem] uppercase tracking-[0.18em] text-zinc-500">Conflicts</div>
              <div class="mt-2 font-medium text-zinc-100">{polling_value(@telegram_polling, :conflict_count)}</div>
              <div class="mt-1 font-mono text-zinc-500">consecutive {polling_value(@telegram_polling, :consecutive_conflicts)}</div>
            </div>
            <div class="rounded-xl border border-white/10 bg-white/[0.03] p-3">
              <div class="text-[0.65rem] uppercase tracking-[0.18em] text-zinc-500">Last poll</div>
              <div class="mt-2 font-medium text-zinc-100">{format_time(polling_value(@telegram_polling, :last_poll_at))}</div>
              <div class="mt-1 font-mono text-zinc-500">updates {polling_value(@telegram_polling, :last_update_count)}</div>
            </div>
          </div>
          <pre :if={polling_value(@telegram_polling, :last_error)} class="mt-3 max-h-40 overflow-auto rounded-xl border border-red-400/20 bg-red-950/20 p-3 text-xs text-red-100">{inspect(polling_value(@telegram_polling, :last_error), pretty: true)}</pre>
        </.panel>

        <.panel title="Telegram actions">
          <div class="flex flex-wrap gap-2">
            <button phx-click="telegram_get_me" class="rounded-lg border border-white/10 px-3 py-2 text-sm text-zinc-200 hover:bg-white/5">getMe</button>
            <button phx-click="telegram_webhook" class="rounded-lg border border-white/10 px-3 py-2 text-sm text-zinc-200 hover:bg-white/5">Webhook info</button>
            <button phx-click="telegram_updates" class="rounded-lg border border-white/10 px-3 py-2 text-sm text-zinc-200 hover:bg-white/5">One-shot getUpdates</button>
            <button phx-click="telegram_start" class="rounded-lg border border-emerald-400/30 px-3 py-2 text-sm text-emerald-200 hover:bg-emerald-400/10">Start polling</button>
            <button phx-click="telegram_stop" class="rounded-lg border border-red-400/30 px-3 py-2 text-sm text-red-200 hover:bg-red-400/10">Stop polling</button>
          </div>
          <pre :if={@action_result} class="mt-4 max-h-80 overflow-auto rounded-xl border border-white/10 bg-black/30 p-3 text-xs text-zinc-300">{@action_result}</pre>
        </.panel>

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
    |> assign_new(:action_result, fn -> nil end)
  end

  defp run_telegram_action(socket, :get_me) do
    result = Exy.Gateway.Telegram.get_me()

    socket
    |> assign(:telegram_info, Map.put(socket.assigns.telegram_info, :get_me, result))
    |> put_action_result(:get_me, result)
  end

  defp run_telegram_action(socket, :webhook) do
    result = Exy.Gateway.Telegram.webhook_info()

    socket
    |> assign(:telegram_info, Map.put(socket.assigns.telegram_info, :webhook, result))
    |> put_action_result(:webhook, result)
  end

  defp run_telegram_action(socket, :updates),
    do: put_action_result(socket, :updates, Exy.Gateway.Telegram.get_updates_once())

  defp put_action_result(socket, action, result) do
    assign(socket, :action_result, inspect({action, redact(result)}, pretty: true, limit: 40))
  end

  defp telegram_info do
    %{get_me: Exy.Gateway.Telegram.get_me(), webhook: Exy.Gateway.Telegram.webhook_info()}
  end

  defp telegram_bot_label({:ok, %{username: username}}) when is_binary(username),
    do: "@#{username}"

  defp telegram_bot_label({:ok, %{first_name: name}}) when is_binary(name), do: name
  defp telegram_bot_label({:error, reason}), do: "Unavailable: #{inspect(reason)}"

  defp telegram_bot_detail({:ok, %{id: id, first_name: name}}), do: "#{id} #{name}"
  defp telegram_bot_detail({:error, _reason}), do: "Check TELEGRAM_BOT_TOKEN"

  defp telegram_webhook_label({:ok, %{url: ""}}), do: "Not configured"
  defp telegram_webhook_label({:ok, %{url: nil}}), do: "Not configured"
  defp telegram_webhook_label({:ok, %{url: url}}) when is_binary(url), do: "Configured"
  defp telegram_webhook_label({:error, reason}), do: "Unavailable: #{inspect(reason)}"

  defp telegram_webhook_detail({:ok, %{url: ""}}), do: "Polling-ready"
  defp telegram_webhook_detail({:ok, %{url: nil}}), do: "Polling-ready"
  defp telegram_webhook_detail({:ok, %{url: url}}), do: url
  defp telegram_webhook_detail({:error, _reason}), do: "Check TELEGRAM_BOT_TOKEN"

  defp polling_state_label({:ok, %{polling?: true}}), do: "Running"
  defp polling_state_label({:ok, _status}), do: "Idle"
  defp polling_state_label({:error, :not_running}), do: "Not running"

  defp polling_value({:ok, status}, key), do: Map.get(status, key, "-")
  defp polling_value({:error, _reason}, _key), do: "-"

  defp redact({:ok, value}), do: {:ok, redact(value)}
  defp redact({:error, value}), do: {:error, redact(value)}
  defp redact(%{token: _token} = value), do: %{value | token: "[redacted]"}
  defp redact(value), do: value

  defp format_time(nil), do: "-"
  defp format_time("-"), do: "-"
  defp format_time(%DateTime{} = time), do: Calendar.strftime(time, "%Y-%m-%d %H:%M:%S")
end
