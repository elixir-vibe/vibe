defmodule Vibe.Session.Store.EventLog do
  @moduledoc "Session event log reads from SQLite storage."
  import Ecto.Query

  alias Vibe.Event
  alias Vibe.Storage.Representation.Event, as: EventRepresentation
  alias Vibe.Storage.Schema.SessionEvent

  @spec session_events(String.t(), (-> [{non_neg_integer(), Event.t()}])) :: [
          {non_neg_integer(), Event.t()}
        ]
  def session_events(session_id, fallback \\ fn -> [] end)
      when is_binary(session_id) and is_function(fallback, 0) do
    events = stored_session_events(session_id)

    case events do
      [] -> fallback.()
      events -> events
    end
  end

  @spec session_events_after(String.t(), non_neg_integer()) :: [{non_neg_integer(), Event.t()}]
  def session_events_after(session_id, seq) when is_binary(session_id) and is_integer(seq) do
    Vibe.Storage.ensure!()

    SessionEvent
    |> where([event], event.session_id == ^session_id and event.seq > ^seq)
    |> order_by([event], event.seq)
    |> Vibe.Repo.all()
    |> Enum.flat_map(&decode_event_record/1)
  end

  defp stored_session_events(session_id) do
    Vibe.Storage.ensure!()

    SessionEvent
    |> where([event], event.session_id == ^session_id)
    |> order_by([event], event.seq)
    |> Vibe.Repo.all()
    |> Enum.flat_map(&decode_event_record/1)
  end

  defp decode_event_record(%SessionEvent{} = event) do
    %{
      "seq" => event.seq,
      "id" => event.event_id,
      "session_id" => event.session_id,
      "type" => event.type,
      "at" => DateTime.to_iso8601(event.at),
      "data" => event.data
    }
    |> EventRepresentation.decode_map()
    |> case do
      {:ok, event} -> [event]
      :error -> []
    end
  end
end
