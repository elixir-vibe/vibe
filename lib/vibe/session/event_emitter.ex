defmodule Vibe.Session.EventEmitter do
  @moduledoc "Applies, persists, and broadcasts session events."

  require Logger

  alias Vibe.Event
  alias Vibe.UI.{PluginBridge, Reducer}

  @notification_ttl_ms 8_000
  @session_list_events [
    :user_message_added,
    :assistant_message_added,
    :assistant_stream_finished,
    :assistant_aborted,
    :status_changed,
    :model_selected,
    :usage_updated
  ]
  @sessions_topic "vibe:sessions"

  @spec emit(map(), Event.t(), keyword()) :: map()
  def emit(state, %Event{} = event, opts \\ []) do
    event = prepare_transient_event(event)
    event_seq = state.event_seq + 1
    persist? = Keyword.get(opts, :persist?, persist_event?(state, event))

    {events, persistence_failed?} =
      events_with_persistence_status(state, event, event_seq, persist?)

    schedule_notification_expiry(event)
    notify_subscribers(state.subscribers, events)

    session_state =
      Enum.reduce(events, state.state, fn {_seq, event}, session_state ->
        Reducer.apply_event(session_state, event)
      end)

    Enum.each(events, fn {_seq, event} -> PluginBridge.dispatch(session_state, event) end)
    if session_list_relevant?(event), do: broadcast_session_change(state.state.session_id)

    %{
      state
      | state: session_state,
        event_seq: event_seq + length(events) - 1,
        events_tail: Enum.reduce(events, state.events_tail, &remember_event/2),
        persistence_failed?: persistence_failed?
    }
  end

  @doc false
  def sessions_topic, do: @sessions_topic

  defp prepare_transient_event(
         %Event{type: :notification_added, data: %Vibe.Event.Notification.Added{} = data} = event
       ) do
    %{event | data: %{data | id: event.id}}
  end

  defp prepare_transient_event(%Event{type: :notification_added} = event) do
    %{event | data: Map.put(event.data, :id, event.id)}
  end

  defp prepare_transient_event(event), do: event

  defp persist_event?(_state, %Event{type: type})
       when type in [:notification_added, :notification_expired], do: false

  defp persist_event?(state, _event), do: state.persist?

  defp schedule_notification_expiry(%Event{type: :notification_added, data: data}) do
    data = event_payload_map(data)
    ttl_ms = Map.get(data, :ttl_ms, @notification_ttl_ms)

    if is_integer(ttl_ms) and ttl_ms > 0 do
      Process.send_after(self(), {:notification_expired, Map.fetch!(data, :id)}, ttl_ms)
    end

    :ok
  end

  defp schedule_notification_expiry(_event), do: :ok

  defp events_with_persistence_status(state, event, event_seq, false) do
    {[{event_seq, event}], state.persistence_failed?}
  end

  defp events_with_persistence_status(state, event, event_seq, true) do
    case Vibe.Session.Store.append_event(event, event_seq) do
      :ok ->
        {[{event_seq, event}], state.persistence_failed?}

      {:error, reason} ->
        Logger.error("Vibe session persistence failed: #{inspect(reason)}")

        failure_event =
          Event.new(
            :notification_added,
            state.state.session_id,
            Vibe.Event.Notification.added(
              level: :error,
              text: "Session persistence failed: #{inspect(reason)}"
            )
          )

        events =
          if state.persistence_failed?,
            do: [{event_seq, event}],
            else: [{event_seq, event}, {event_seq + 1, failure_event}]

        {events, true}
    end
  end

  defp notify_subscribers(subscribers, events) do
    Enum.each(events, fn {_seq, event} ->
      Enum.each(subscribers, fn {_ref, pid} -> send(pid, {Vibe.Session, :event, event}) end)
    end)
  end

  defp event_payload_map(%struct{} = payload) when is_atom(struct) do
    payload
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp event_payload_map(payload) when is_map(payload), do: payload

  defp remember_event({seq, event}, tail) do
    tail |> Vibe.Support.Lists.append({seq, event}) |> Enum.take(-200)
  end

  defp session_list_relevant?(%{type: type}) when type in @session_list_events, do: true
  defp session_list_relevant?(_event), do: false

  @spec broadcast_session_change(String.t()) :: :ok
  def broadcast_session_change(session_id) do
    Phoenix.PubSub.broadcast(Vibe.PubSub, @sessions_topic, {:session_changed, session_id})
  rescue
    _error -> :ok
  end
end
