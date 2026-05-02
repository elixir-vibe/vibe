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
      <div class="rounded-xl border border-red-400/30 bg-red-400/10 p-6 text-red-100">{@error}</div>
    </.app_shell>
    """
  end

  def render(assigns) do
    ~H"""
    <.app_shell current={:sessions} title="Session workbench" subtitle={@session_id}>
      <:actions>
        <.link navigate={~p"/"} class="rounded-lg border border-white/10 px-3 py-2 text-sm text-zinc-300 transition-colors hover:border-orange-300/50 hover:text-orange-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70 sm:px-4">All sessions</.link>
      </:actions>

      <:sidebar>
        <.panel title="Session">
          <div class="space-y-3 text-sm text-zinc-300">
            <div><p class="text-[0.68rem] uppercase tracking-[0.2em] text-zinc-500">Workspace</p><p class="mt-1 break-words font-mono text-xs [overflow-wrap:anywhere]">{@ui_state.cwd}</p></div>
            <div class="flex min-w-0 justify-between gap-4"><span class="text-zinc-500">Model</span><span class="truncate">{@ui_state.model}</span></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Status</span><.status_badge status={@ui_state.status} /></div>
            <div class="flex justify-between gap-4"><span class="text-zinc-500">Messages</span><span class="tabular-nums">{length(@ui_state.messages)}</span></div>
          </div>
        </.panel>
      </:sidebar>

      <:mobile_meta>
        <div class="rounded-xl border border-white/10 bg-[#17151d]/78 p-3 text-xs text-zinc-400">
          <div class="flex items-center justify-between gap-3">
            <.status_badge status={@ui_state.status} />
            <span class="tabular-nums">{length(@ui_state.messages)} messages</span>
          </div>
          <p class="mt-2 truncate">{@ui_state.model}</p>
          <p class="mt-1 truncate font-mono">{@ui_state.cwd}</p>
        </div>
      </:mobile_meta>

      <:inspector>
        <.panel title="Runtime">
          <div class="space-y-3 text-sm text-zinc-300">
            <div class="flex justify-between"><span class="text-zinc-500">Cursor</span><span class="tabular-nums">{@cursor}</span></div>
            <div class="flex justify-between"><span class="text-zinc-500">Pending tools</span><span class="tabular-nums">{map_size(@ui_state.pending_tools || %{})}</span></div>
            <div class="flex justify-between"><span class="text-zinc-500">Notifications</span><span class="tabular-nums">{length(@ui_state.notifications || [])}</span></div>
          </div>
        </.panel>
      </:inspector>

      <section class="rounded-xl border border-white/10 bg-[#121016]/80">
        <div id="messages" phx-hook="ScrollBottom" class="min-h-[48vh] px-3 py-3 sm:px-4 sm:py-4">
          <div class="flex flex-col gap-3">
            <%= if @ui_state.messages == [] and is_nil(@ui_state.streaming_message) do %>
              <div class="rounded-xl border border-dashed border-white/15 p-8 text-center text-sm text-zinc-500">No messages yet. Start with the composer below.</div>
            <% end %>

            <%= for message <- display_messages(@ui_state.messages, @session_id) do %>
              <.message_card message={message} />
            <% end %>

            <%= if @ui_state.streaming_message && @assistant_texts == [] do %>
              <article class="max-w-full rounded-xl border border-cyan-300/25 bg-cyan-300/10 px-4 py-3 sm:px-5 sm:py-4">
                <div class="mb-2 text-[0.68rem] font-semibold uppercase tracking-[0.22em] text-cyan-200">assistant streaming</div>
                <div class="whitespace-pre-wrap break-words font-sans text-sm leading-6 text-zinc-100 [overflow-wrap:anywhere]">{@ui_state.streaming_message.text}</div>
              </article>
            <% end %>
          </div>
        </div>

        <form phx-submit="submit" class="border-t border-white/10 bg-[#17151d]/90 p-3 sm:p-4">
          <label class="sr-only" for="session-prompt">Message Exy</label>
          <textarea id="session-prompt" name="prompt" value={@prompt} rows="2" autocomplete="off" placeholder="Ask Exy. Use /help, /model, /sessions, or plain language…" class="min-h-16 w-full resize-y rounded-lg border border-white/10 bg-[#0d0c11]/85 px-3 py-2 text-sm leading-6 text-zinc-100 ring-orange-300/20 placeholder:text-zinc-600 focus:border-orange-300 focus:outline-none focus:ring-4 sm:min-h-20"></textarea>
          <div class="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <p class="text-xs leading-5 text-zinc-500">Server-owned session state.</p>
            <div class="flex justify-end gap-2">
              <button type="button" phx-click="cancel" class="rounded-lg border border-white/10 px-4 py-2 text-sm text-zinc-300 transition-colors hover:border-red-300/50 hover:text-red-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-300/60">Cancel</button>
              <button class="rounded-lg bg-orange-400 px-5 py-2 text-sm font-semibold text-zinc-950 shadow-lg shadow-orange-950/20 transition-colors hover:bg-orange-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">Send</button>
            </div>
          </div>
        </form>
      </section>
    </.app_shell>
    """
  end

  defp display_messages(messages, session_id) do
    canonical =
      if polluted_tui_transcript?(messages), do: canonical_messages(session_id), else: []

    case canonical do
      [] -> semantic_messages(messages)
      messages -> messages
    end
  end

  defp semantic_messages(messages) do
    messages
    |> Enum.reduce({[], false}, fn message, {acc, dropping?} ->
      cond do
        tui_transcript_start?(message) -> {acc, true}
        dropping? and Map.get(message, :role) == :user -> {acc, true}
        Map.get(message, :streaming?) -> {acc, false}
        true -> {[message | acc], false}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp polluted_tui_transcript?(messages) do
    Enum.any?(messages, &tui_transcript_start?/1) or tui_transcript_fragments?(messages)
  end

  defp tui_transcript_fragments?(messages) do
    messages
    |> Enum.reduce_while(0, fn message, count ->
      count = if tui_transcript_fragment?(message), do: count + 1, else: count
      if count > 5, do: {:halt, true}, else: {:cont, count}
    end)
    |> Kernel.==(true)
  end

  defp canonical_messages(session_id) do
    session_id
    |> Exy.Session.Store.events()
    |> Enum.filter(&(&1.type in [:user_message, :assistant_message]))
    |> Enum.reduce({[], false}, fn event, {acc, seen_user?} ->
      case canonical_message(event, seen_user?) do
        {nil, seen_user?} -> {acc, seen_user?}
        {message, seen_user?} -> {[message | acc], seen_user?}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp canonical_message(%{type: :user_message}, true), do: {nil, true}

  defp canonical_message(event, seen_user?) do
    case canonical_message(event) do
      nil -> {nil, seen_user?}
      %{role: :user} = message -> {message, true}
      message -> {message, seen_user?}
    end
  end

  defp canonical_message(%{type: :user_message, at: at, data: %{prompt: prompt}}) do
    prompt = prompt |> strip_recalled_history() |> String.trim()

    if tui_transcript_text?(prompt), do: nil, else: %{role: :user, text: prompt, at: at}
  end

  defp canonical_message(%{type: :assistant_message, at: at} = event) do
    case assistant_text(event) do
      text when is_binary(text) and text != "" -> %{role: :assistant, text: text, at: at}
      _text -> nil
    end
  end

  defp canonical_message(_event), do: nil

  defp tui_transcript_start?(%{role: :user, text: "◆ " <> _rest}), do: true
  defp tui_transcript_start?(_message), do: false

  defp tui_transcript_fragment?(%{role: :user, text: text}) when is_binary(text) do
    tui_transcript_text?(text)
  end

  defp tui_transcript_fragment?(_message), do: false

  defp tui_transcript_text?("◆ " <> _rest), do: true

  defp tui_transcript_text?(text) when is_binary(text) do
    text == "" or
      String.starts_with?(text, ["… (", "──", "│ "]) or
      String.contains?(text, "ctrl+o to expand")
  end

  defp tui_transcript_text?(_text), do: false

  defp strip_recalled_history(prompt) do
    prompt
    |> String.replace(~r/\n\n<recalled-history>.*?<\/recalled-history>/s, "")
  end

  defp assistant_texts(session_id) do
    session_id
    |> Exy.Session.Store.events()
    |> Enum.filter(&(&1.type == :assistant_message))
    |> Enum.map(&assistant_text/1)
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp assistant_text(%{data: %{result: %{output: output}}}), do: output
  defp assistant_text(%{data: %{result: %{"output" => output}}}), do: output
  defp assistant_text(%{data: %{text: text}}), do: text
  defp assistant_text(_event), do: nil

  defp get_or_start_session(session_id) do
    case Exy.Session.lookup(session_id) do
      {:ok, session} -> {:ok, session}
      {:error, :not_found} -> Exy.Session.start(session_id: session_id)
    end
  end

  defp assign_session(socket, session, state, cursor) do
    socket
    |> assign(session: session, session_id: state.session_id, prompt: "")
    |> assign(:assistant_texts, assistant_texts(state.session_id))
    |> assign_state(state, cursor)
  end

  defp assign_state(socket, state, cursor) do
    assign(socket, ui_state: state, view_model: ViewModel.from_state(state), cursor: cursor)
  end
end
