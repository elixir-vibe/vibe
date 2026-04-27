defmodule Exy.Web.SessionLive do
  @moduledoc false

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
  def render(assigns) do
    ~H"""
    <main class="mx-auto flex h-screen w-full max-w-6xl flex-col px-6 py-6">
      <header class="mb-4 flex items-center justify-between border-b border-zinc-800 pb-4">
        <div class="min-w-0">
          <.link navigate={~p"/"} class="text-xs uppercase tracking-[0.25em] text-cyan-300/80">Exy</.link>
          <h1 class="mt-1 truncate font-mono text-sm text-zinc-300">{@session_id}</h1>
          <p class="mt-1 truncate text-xs text-zinc-500">{@ui_state.cwd}</p>
        </div>
        <div class="flex items-center gap-3 text-xs text-zinc-400">
          <span class="rounded-full bg-zinc-900 px-3 py-1">{@ui_state.status}</span>
          <span>{@ui_state.model}</span>
        </div>
      </header>

      <section id="messages" phx-hook="ScrollBottom" class="min-h-0 flex-1 overflow-y-auto rounded-2xl border border-zinc-800 bg-zinc-950/80 p-4">
        <div class="flex flex-col gap-4">
          <%= for message <- @ui_state.messages do %>
            <article class={message_class(message.role)}>
              <div class="mb-2 text-xs font-semibold uppercase tracking-wider opacity-70">{message.role}</div>
              <pre class="whitespace-pre-wrap font-sans text-sm leading-6">{message_text(message)}</pre>
            </article>
          <% end %>

          <%= if @ui_state.streaming_message do %>
            <article class="rounded-2xl border border-cyan-500/30 bg-cyan-950/20 p-4">
              <div class="mb-2 text-xs font-semibold uppercase tracking-wider text-cyan-300">assistant streaming</div>
              <pre class="whitespace-pre-wrap font-sans text-sm leading-6">{@ui_state.streaming_message.text}</pre>
            </article>
          <% end %>
        </div>
      </section>

      <form phx-submit="submit" class="mt-4 flex gap-3">
        <textarea name="prompt" value={@prompt} rows="3" placeholder="Ask Exy..." class="min-h-24 flex-1 resize-none rounded-2xl border border-zinc-800 bg-zinc-900 px-4 py-3 text-sm text-zinc-100 outline-none ring-cyan-400/30 placeholder:text-zinc-600 focus:border-cyan-400 focus:ring-4"></textarea>
        <div class="flex w-28 flex-col gap-2">
          <button class="rounded-xl bg-cyan-400 px-4 py-3 text-sm font-semibold text-zinc-950 hover:bg-cyan-300">Send</button>
          <button type="button" phx-click="cancel" class="rounded-xl border border-zinc-700 px-4 py-3 text-sm text-zinc-300 hover:bg-zinc-900">Cancel</button>
        </div>
      </form>
    </main>
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

  defp message_class(:user), do: "self-end rounded-2xl bg-cyan-400 px-4 py-3 text-zinc-950"

  defp message_class(:assistant),
    do: "rounded-2xl border border-zinc-800 bg-zinc-900 px-4 py-3 text-zinc-100"

  defp message_class(_role),
    do: "rounded-2xl border border-zinc-800 bg-zinc-950 px-4 py-3 text-zinc-300"

  defp message_text(%{text: text}) when is_binary(text), do: text
  defp message_text(%{result: result}), do: inspect(result, pretty: true, limit: 40)
  defp message_text(%{error: error}), do: error
  defp message_text(message), do: inspect(message, pretty: true, limit: 40)
end
