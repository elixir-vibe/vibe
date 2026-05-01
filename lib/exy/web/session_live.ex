defmodule Exy.Web.SessionLive do
  @moduledoc """
  LiveView workbench for one Exy agent session.
  """
  use Exy.Web, :live_view

  alias Exy.UI.{Reducer, ViewModel}

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    with {:ok, session} <- get_or_start_session(session_id),
         {:ok, state, cursor} <- Exy.Session.attach(session, self()) do
      {:ok, assign_session(socket, session, state, cursor)}
    else
      {:error, reason} -> {:ok, assign(socket, error: inspect(reason))}
    end
  end

  @impl true
  def handle_event("submit", %{"prompt" => prompt}, socket) when is_binary(prompt) do
    prompt = String.trim(prompt)

    if prompt != "" do
      :ok = Exy.Session.dispatch(socket.assigns.session, {:submit_prompt, %{text: prompt}})
    end

    {:noreply, assign(socket, prompt: "")}
  end

  def handle_event("cancel", _params, socket) do
    :ok = Exy.Session.dispatch(socket.assigns.session, :cancel_stream)
    {:noreply, socket}
  end

  @impl true
  def handle_info({Exy.Session, :event, event}, socket) do
    state = Reducer.apply_event(socket.assigns.ui_state, event)
    {:noreply, assign_state(socket, state, socket.assigns.cursor + 1)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if connected?(socket) and Map.has_key?(socket.assigns, :session) do
      Exy.Session.detach(socket.assigns.session, self())
    end

    :ok
  end

  @impl true
  def render(%{error: _error} = assigns) do
    ~H"""
    <.app_shell current={:sessions} title="Session unavailable">
      <div class="rounded-2xl border border-red-400/30 bg-red-400/10 p-6 text-red-100">{@error}</div>
    </.app_shell>
    """
  end

  def render(assigns) do
    ~H"""
    <.app_shell current={:sessions} title="Session workbench" subtitle={@session_id}>
      <:actions>
        <.link navigate={~p"/"} class="rounded-xl border border-white/10 px-4 py-2 text-sm text-zinc-300 hover:border-orange-300/50 hover:text-orange-100">All sessions</.link>
      </:actions>

      <:sidebar>
        <.panel title="Session">
          <div class="space-y-3 text-sm text-zinc-300">
            <div><p class="text-xs uppercase tracking-[0.2em] text-zinc-500">Workspace</p><p class="mt-1 break-all font-mono text-xs">{@ui_state.cwd}</p></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Model</span><span class="truncate">{@ui_state.model}</span></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Status</span><.status_badge status={@ui_state.status} /></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Messages</span><span>{length(@ui_state.messages)}</span></div>
          </div>
        </.panel>
      </:sidebar>

      <:inspector>
        <.panel title="Runtime">
          <div class="space-y-3 text-sm text-zinc-300">
            <div class="flex justify-between"><span class="text-zinc-500">Cursor</span><span>{@cursor}</span></div>
            <div class="flex justify-between"><span class="text-zinc-500">Pending tools</span><span>{map_size(@ui_state.pending_tools || %{})}</span></div>
            <div class="flex justify-between"><span class="text-zinc-500">Notifications</span><span>{length(@ui_state.notifications || [])}</span></div>
          </div>
        </.panel>
      </:inspector>

      <section id="messages" phx-hook="ScrollBottom" class="min-h-[55vh] overflow-y-auto rounded-3xl border border-white/10 bg-zinc-950/55 p-4 shadow-2xl shadow-black/30">
        <div class="flex flex-col gap-4">
          <%= for message <- @ui_state.messages do %>
            <.message_card message={message} />
          <% end %>

          <%= if @ui_state.streaming_message do %>
            <article class="rounded-2xl border border-cyan-300/25 bg-cyan-300/10 p-4">
              <div class="mb-2 text-xs font-semibold uppercase tracking-[0.2em] text-cyan-200">assistant streaming</div>
              <pre class="whitespace-pre-wrap font-sans text-sm leading-6 text-zinc-100">{@ui_state.streaming_message.text}</pre>
            </article>
          <% end %>
        </div>
      </section>

      <form phx-submit="submit" class="mt-4 rounded-3xl border border-white/10 bg-zinc-900/70 p-3 shadow-xl shadow-black/20">
        <textarea name="prompt" value={@prompt} rows="4" placeholder="Ask Exy. Use /help, /model, /sessions, or plain language." class="min-h-28 w-full resize-y rounded-2xl border border-white/10 bg-zinc-950/80 px-4 py-3 text-sm leading-6 text-zinc-100 outline-none ring-orange-300/20 placeholder:text-zinc-600 focus:border-orange-300 focus:ring-4"></textarea>
        <div class="mt-3 flex items-center justify-between gap-3">
          <p class="text-xs text-zinc-500">Cmd/Ctrl+Enter support can be added as a LiveView hook; state stays server-owned.</p>
          <div class="flex gap-2">
            <button type="button" phx-click="cancel" class="rounded-xl border border-white/10 px-4 py-2 text-sm text-zinc-300 hover:border-red-300/50 hover:text-red-100">Cancel</button>
            <button class="rounded-xl bg-orange-400 px-5 py-2 text-sm font-semibold text-zinc-950 shadow-lg shadow-orange-950/30 hover:bg-orange-300">Send</button>
          </div>
        </div>
      </form>
    </.app_shell>
    """
  end

  defp get_or_start_session(session_id) do
    case Exy.Session.lookup(session_id) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> Exy.Session.start(session_id: session_id)
    end
  end

  defp assign_session(socket, session, state, cursor) do
    socket
    |> assign(session: session, session_id: state.session_id, prompt: "")
    |> assign_state(state, cursor)
  end

  defp assign_state(socket, state, cursor) do
    assign(socket, ui_state: state, view_model: ViewModel.from_state(state), cursor: cursor)
  end
end
