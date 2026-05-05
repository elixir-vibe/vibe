defmodule Exy.Web.SessionLive do
  @moduledoc "LiveView workbench for one Exy agent session."
  use Exy.Web, :live_view

  alias Exy.UI.{Reducer, ViewModel}
  alias Exy.Web.Session.{Messages, Status}

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
      :ok = Exy.Session.dispatch(socket.assigns.session, submit_prompt_command(prompt, socket))
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

    socket =
      socket
      |> assign_final_assistant_message(event)
      |> assign_state(state, socket.assigns.cursor + 1)

    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp submit_prompt_command(prompt, socket) do
    root = socket.assigns.ui_state.cwd || File.cwd!()

    case Exy.Prompt.Attachments.expand(prompt, root: root) do
      expanded when is_list(expanded) -> {:submit_prompt, %{text: prompt, content: expanded}}
      _text -> {:submit_prompt, %{text: prompt}}
    end
  end

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
        <button :if={Status.working?(@ui_state)} type="button" phx-click="cancel" class="rounded-lg border border-red-300/30 bg-red-400/10 px-3 py-2 text-sm font-medium text-red-100 transition-colors hover:border-red-300/60 hover:bg-red-400/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-300/60 sm:px-4">Stop</button>
      </:actions>

      <:sidebar>
        <.session_sidebar state={@ui_state} />
      </:sidebar>

      <:mobile_meta>
        <.mobile_meta state={@ui_state} />
      </:mobile_meta>

      <:inspector>
        <.runtime_inspector state={@ui_state} cursor={@cursor} />
        <.tool_timeline state={@ui_state} />
      </:inspector>

      <.link navigate={~p"/"} class="mb-3 inline-flex text-sm text-zinc-500 hover:text-zinc-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">← Sessions</.link>

      <.status_strip state={@ui_state} />

      <section class="rounded-xl border border-white/10 bg-[#121016]/80">
        <.transcript state={@ui_state} final_assistant_messages={@final_assistant_messages} />
        <.composer state={@ui_state} prompt={@prompt} />
      </section>
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
    |> assign(:final_assistant_messages, [])
    |> assign_state(state, cursor)
  end

  defp assign_final_assistant_message(socket, %{
         type: :assistant_stream_finished,
         data: %{text: text},
         at: at
       })
       when is_binary(text) and text != "" do
    messages =
      socket.assigns
      |> Map.get(:final_assistant_messages, [])
      |> Messages.append_final_assistant(%{role: :assistant, text: text, at: at})

    assign(socket, :final_assistant_messages, messages)
  end

  defp assign_final_assistant_message(socket, _event), do: socket

  defp assign_state(socket, state, cursor) do
    assign(socket, ui_state: state, view_model: ViewModel.from_state(state), cursor: cursor)
  end
end
