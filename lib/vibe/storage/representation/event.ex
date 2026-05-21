defmodule Vibe.Storage.Representation.Event do
  @moduledoc "Current storage representation for semantic session events."

  @enforce_keys [:id, :type, :session_id, :at, :data]
  defstruct [:id, :type, :session_id, :at, :data, :seq]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          session_id: String.t(),
          at: DateTime.t(),
          data: map(),
          seq: non_neg_integer() | nil
        }
end

defimpl Vibe.Storage.Persistable, for: Vibe.UI.Event do
  def persist(event) do
    %Vibe.Storage.Representation.Event{
      id: event.id,
      type: event.type,
      session_id: event.session_id,
      at: event.at,
      data: persist_data(event.type, event.data)
    }
  end

  defp persist_data(type, %Vibe.Tool.Event{} = event)
       when type in [:tool_started, :tool_updated, :tool_finished] do
    Vibe.Storage.Persistable.persist(event)
  end

  defp persist_data(type, %{goal: %Vibe.Goals.Goal{} = goal} = data)
       when type in [:goal_set, :goal_updated] do
    %{data | goal: Vibe.Storage.Persistable.persist(goal)}
  end

  defp persist_data(type, %{alert: %Vibe.SystemAlarms.Alert{} = alert})
       when type in [:runtime_alert_set, :runtime_alert_clear] do
    %{alert: Vibe.Storage.Persistable.persist(alert)}
  end

  defp persist_data(_type, data), do: data
end

defimpl Jason.Encoder, for: Vibe.Storage.Representation.Event do
  def encode(event, opts) do
    %{
      id: event.id,
      type: event.type,
      session_id: event.session_id,
      at: event.at,
      data: event.data
    }
    |> maybe_put_seq(event.seq)
    |> Vibe.JSON.Encode.value()
    |> Jason.Encode.map(opts)
  end

  defp maybe_put_seq(map, nil), do: map
  defp maybe_put_seq(map, seq), do: Map.put(map, :seq, seq)
end
