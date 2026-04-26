defmodule Exy.Web.SessionLive do
  @moduledoc """
  Minimal LiveView-shaped session surface.

  The module intentionally avoids a compile-time Phoenix dependency. It consumes
  the same server-owned `Exy.Session.attach/3` snapshots and semantic UI events
  as the TUI.
  """

  alias Exy.UI.{Reducer, State, ViewModel}

  @type socket :: %{assigns: map()}

  @spec mount(map(), map(), socket()) :: {:ok, socket()} | {:error, term()}
  def mount(%{"session_id" => session_id}, _session, socket) do
    with {:ok, session} <- Exy.Session.lookup(session_id),
         {:ok, state, cursor} <- Exy.Session.attach(session, self()) do
      {:ok, assign_session(socket, session, state, cursor)}
    end
  end

  def mount(_params, _session, socket) do
    with {:ok, session} <- Exy.Session.start(),
         {:ok, state, cursor} <- Exy.Session.attach(session, self()) do
      {:ok, assign_session(socket, session, state, cursor)}
    end
  end

  @spec handle_event(String.t(), map(), socket()) :: {:noreply, socket()}
  def handle_event("submit", %{"prompt" => prompt}, %{assigns: %{session: session}} = socket)
      when is_binary(prompt) do
    :ok = Exy.Session.dispatch(session, {:submit_prompt, %{text: prompt}})
    {:noreply, socket}
  end

  def handle_event("cancel", _params, %{assigns: %{session: session}} = socket) do
    :ok = Exy.Session.dispatch(session, :cancel_stream)
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @spec handle_info(term(), socket()) :: {:noreply, socket()}
  def handle_info(
        {Exy.Session, :event, event},
        %{assigns: %{ui_state: state, cursor: cursor}} = socket
      ) do
    state = Reducer.apply_event(state, event)

    {:noreply,
     assign(socket, ui_state: state, view_model: ViewModel.from_state(state), cursor: cursor + 1)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @spec render_model(State.t()) :: map()
  def render_model(%State{} = state), do: ViewModel.from_state(state)

  defp assign_session(socket, session, state, cursor) do
    assign(socket,
      session: session,
      session_id: state.session_id,
      ui_state: state,
      view_model: ViewModel.from_state(state),
      cursor: cursor
    )
  end

  defp assign(%{assigns: assigns} = socket, kv) do
    %{socket | assigns: Map.merge(assigns, Map.new(kv))}
  end
end
