defmodule Vibe.Storage.Representation.SessionLog do
  @moduledoc "Current storage representation boundary for persisted session log entries."
  alias Vibe.Trajectory
  alias Vibe.Event

  @json_atom_keys MapSet.new([
                    "alert",
                    "args",
                    "at",
                    "content",
                    "context",
                    "created_at",
                    "cwd",
                    "data",
                    "detail",
                    "error",
                    "filename",
                    "goal",
                    "goal_id",
                    "height",
                    "id",
                    "image",
                    "input_tokens",
                    "image_count",
                    "kind",
                    "level",
                    "lifecycle",
                    "mime_type",
                    "model",
                    "name",
                    "objective",
                    "output",
                    "output_format",
                    "output_parts",
                    "output_tokens",
                    "overlay_kind",
                    "parts",
                    "path",
                    "phase",
                    "placement",
                    "prompt",
                    "result",
                    "role",
                    "selector_kind",
                    "session_id",
                    "seq",
                    "severity",
                    "size_bytes",
                    "source",
                    "status",
                    "text",
                    "time_used_seconds",
                    "token_budget",
                    "tokens_used",
                    "tool_call_id",
                    "tool_name",
                    "total_cost",
                    "total_tokens",
                    "type",
                    "updated_at",
                    "usage",
                    "width"
                  ])

  @spec encode_trajectory(Trajectory.t()) :: map()
  def encode_trajectory(%Trajectory{} = event) do
    event
    |> Jason.encode!()
    |> Jason.decode!()
  end

  @spec encode_ui_event(Event.t(), non_neg_integer()) :: map()
  def encode_ui_event(%Event{} = event, seq) do
    event
    |> Vibe.Storage.Persistable.persist()
    |> Map.put(:seq, seq)
    |> Jason.encode!()
    |> Jason.decode!()
  end

  @spec decode_ui_event_map(map()) :: {:ok, {non_neg_integer(), Event.t()}} | :error
  def decode_ui_event_map(map), do: decode_ui_event(map)

  @spec decode_ui_event_line(String.t()) :: [{non_neg_integer(), Event.t()}]
  def decode_ui_event_line(line) do
    with {:ok, %{"entry_type" => "ui_event"} = map} <- Jason.decode(line),
         {:ok, event} <- decode_ui_event(map) do
      [event]
    else
      _ -> []
    end
  end

  @spec decode_trajectory_map(map()) :: {:ok, Trajectory.t()} | :error
  def decode_trajectory_map(map), do: decode_trajectory(map)

  @spec decode_trajectory_line(String.t()) :: [Trajectory.t()]
  def decode_trajectory_line(line) do
    with {:ok, map} <- Jason.decode(line),
         true <- Map.get(map, "entry_type", "trajectory") == "trajectory",
         {:ok, event} <- decode_trajectory(map) do
      [event]
    else
      _ -> []
    end
  end

  @spec project_trajectory_events([Trajectory.t()]) :: [{pos_integer(), Event.t()}]
  def project_trajectory_events(events) do
    events
    |> Enum.flat_map(&project_trajectory_event/1)
    |> Enum.with_index(1)
    |> Enum.map(fn {event, seq} -> {seq, event} end)
  end

  defp decode_ui_event(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]),
         {:ok, type} <- decode_event_type(map["type"]) do
      data = map |> Map.get("data", %{}) |> atomize_keys() |> decode_ui_event_data(type)

      {:ok,
       {map["seq"],
        Event.new(type, map["session_id"], data,
          id: map["id"],
          at: at
        )}}
    end
  rescue
    _exception -> :error
  end

  defp decode_trajectory(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]),
         {:ok, type} <- decode_trajectory_type(map["type"]) do
      {:ok,
       Trajectory.new(type, atomize_keys(map["data"] || %{}),
         id: map["id"],
         session_id: map["session_id"],
         at: at
       )}
    end
  rescue
    _exception -> :error
  end

  defp project_trajectory_event(%Trajectory{
         type: :user_message,
         session_id: session_id,
         at: at,
         data: data
       }) do
    text = Map.get(data, :prompt, "")
    [Event.new(:user_message_added, session_id, %{text: text}, at: at)]
  end

  defp project_trajectory_event(%Trajectory{
         type: :assistant_message,
         session_id: session_id,
         at: at,
         data: data
       }) do
    payload =
      case Map.fetch(data, :error) do
        {:ok, error} -> %{error: error}
        :error -> %{result: Map.get(data, :result) || data}
      end

    [Event.new(:assistant_message_added, session_id, payload, at: at)]
  end

  defp project_trajectory_event(%Trajectory{
         type: :llm_usage,
         session_id: session_id,
         at: at,
         data: data
       }) do
    [Event.new(:usage_updated, session_id, data, at: at)]
  end

  defp project_trajectory_event(_event), do: []

  defp decode_ui_event_data(data, type)
       when type in [:tool_started, :tool_updated, :tool_finished] and is_map(data) do
    data
    |> Vibe.Storage.Representation.ToolEvent.decode!()
    |> Vibe.Storage.Restorable.restore()
  end

  defp decode_ui_event_data(%{effort: effort} = data, :effort_selected) when is_binary(effort) do
    case Vibe.Model.Effort.from_string(effort) do
      {:ok, effort} -> %{data | effort: effort}
      {:error, _reason} -> data
    end
  end

  defp decode_ui_event_data(%{status: status} = data, :status_changed) when is_binary(status),
    do: %{data | status: existing_atom_or_string(status)}

  defp decode_ui_event_data(%{goal: goal} = data, type) when type in [:goal_set, :goal_updated] do
    %{data | goal: decode_goal(goal)}
  end

  defp decode_ui_event_data(%{alert: alert} = data, type)
       when type in [:runtime_alert_set, :runtime_alert_clear] do
    %{data | alert: decode_runtime_alert(alert)}
  end

  defp decode_ui_event_data(%{level: level} = data, :notification_added) when is_binary(level),
    do: %{data | level: existing_atom_or_string(level)}

  defp decode_ui_event_data(data, _type), do: data

  defp decode_goal(goal) when is_map(goal) do
    goal
    |> Vibe.Storage.Representation.Goal.decode!()
    |> Vibe.Storage.Restorable.restore()
  end

  defp decode_goal(goal), do: goal

  defp decode_runtime_alert(alert) when is_map(alert) do
    alert
    |> Vibe.Storage.Representation.RuntimeAlert.decode!()
    |> Vibe.Storage.Restorable.restore()
  end

  defp decode_runtime_alert(alert), do: alert

  defp decode_event_type(type), do: decode_existing_atom(type)
  defp decode_trajectory_type(type), do: decode_existing_atom(type)

  defp decode_existing_atom(type) when is_binary(type) do
    {:ok, String.to_existing_atom(type)}
  rescue
    ArgumentError -> :error
  end

  defp decode_existing_atom(_type), do: :error

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      atom_key = atomize_key(key)
      {atom_key, decode_json_value(atom_key, value)}
    end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value

  defp decode_json_value(key, value)
       when key in [
              :kind,
              :overlay_kind,
              :selector_kind,
              :direction,
              :status,
              :level,
              :placement,
              :type,
              :phase,
              :role,
              :lifecycle
            ] and is_binary(value),
       do: existing_atom_or_string(value)

  defp decode_json_value(_key, value), do: atomize_keys(value)

  defp atomize_key(key) when is_binary(key) do
    if MapSet.member?(@json_atom_keys, key), do: String.to_existing_atom(key), else: key
  end

  defp atomize_key(key), do: key

  defp existing_atom_or_string(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end
end
