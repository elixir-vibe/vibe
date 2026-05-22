defmodule Vibe.Storage.Representation.Event do
  @moduledoc "Storage representation for semantic session events."

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
                    "direction",
                    "error",
                    "filename",
                    "goal",
                    "goal_id",
                    "height",
                    "key",
                    "label",
                    "id",
                    "image",
                    "image_count",
                    "input_tokens",
                    "kind",
                    "level",
                    "lifecycle",
                    "mime_type",
                    "message",
                    "model",
                    "name",
                    "objective",
                    "overlay",
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
                    "seq",
                    "session_id",
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

  @spec encode(Vibe.Event.t(), non_neg_integer()) :: map()
  def encode(%Vibe.Event{} = event, seq) do
    event
    |> Vibe.Storage.Persistable.persist()
    |> Map.put(:seq, seq)
    |> Jason.encode!()
    |> Jason.decode!()
  end

  @spec decode_map(map()) :: {:ok, {non_neg_integer(), Vibe.Event.t()}} | :error
  def decode_map(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]),
         {:ok, type} <- decode_event_type(map["type"]) do
      data = map |> Map.get("data", %{}) |> atomize_keys() |> decode_event_data(type)

      {:ok,
       {map["seq"],
        Vibe.Event.new(type, map["session_id"], data,
          id: map["id"],
          at: at
        )}}
    end
  rescue
    _exception -> :error
  end

  @spec decode_line(String.t()) :: [{non_neg_integer(), Vibe.Event.t()}]
  def decode_line(line) do
    with {:ok, %{"entry_type" => "session_event"} = map} <- Jason.decode(line),
         {:ok, event} <- decode_map(map) do
      [event]
    else
      _ -> []
    end
  end

  defp decode_event_data(data, :tool_started) when is_map(data) do
    data
    |> decode_tool_event()
    |> Vibe.Event.Tool.started()
  end

  defp decode_event_data(data, :tool_updated) when is_map(data) do
    data
    |> decode_tool_event()
    |> Vibe.Event.Tool.updated()
  end

  defp decode_event_data(data, :tool_finished) when is_map(data) do
    data
    |> decode_tool_event()
    |> Vibe.Event.Tool.finished()
  end

  defp decode_event_data(data, :user_message_added), do: Vibe.Event.Message.user_added(data)

  defp decode_event_data(data, :assistant_message_added),
    do: Vibe.Event.Message.assistant_added(data)

  defp decode_event_data(_data, :messages_cleared), do: Vibe.Event.Message.cleared()

  defp decode_event_data(_data, :assistant_stream_started),
    do: Vibe.Event.AssistantStream.started()

  defp decode_event_data(%{text: text}, :assistant_delta),
    do: Vibe.Event.AssistantStream.delta(text)

  defp decode_event_data(%{text: text}, :assistant_thinking_delta),
    do: Vibe.Event.AssistantStream.thinking_delta(text)

  defp decode_event_data(data, :assistant_stream_finished) do
    data |> Map.get(:text) |> Vibe.Event.AssistantStream.finished()
  end

  defp decode_event_data(data, :assistant_aborted), do: Vibe.Event.AssistantStream.aborted(data)

  defp decode_event_data(data, :notification_added), do: Vibe.Event.Notification.added(data)

  defp decode_event_data(%{id: id}, :notification_expired),
    do: Vibe.Event.Notification.expired(id)

  defp decode_event_data(%{session_id: session_id}, :session_selected),
    do: Vibe.Event.Session.selected(session_id)

  defp decode_event_data(_data, :session_new_requested), do: Vibe.Event.Session.new_requested()

  defp decode_event_data(_data, :session_backgrounded), do: Vibe.Event.Session.backgrounded()

  defp decode_event_data(%{count: count}, :active_sessions_updated),
    do: Vibe.Event.Session.active_count_updated(count)

  defp decode_event_data(data, :selector_opened), do: Vibe.Event.Selector.opened(data)

  defp decode_event_data(%{direction: direction}, :selector_moved),
    do: Vibe.Event.Selector.moved(direction)

  defp decode_event_data(_data, :selector_closed), do: Vibe.Event.Selector.closed()

  defp decode_event_data(data, :selector_confirmed), do: Vibe.Event.Selector.confirmed(data)

  defp decode_event_data(%{tokens_before: tokens_before}, :context_compaction_started),
    do: Vibe.Event.ContextCompaction.started(tokens_before)

  defp decode_event_data(%{summary: summary}, :context_compaction_finished),
    do: Vibe.Event.ContextCompaction.finished(summary)

  defp decode_event_data(%{reason: reason}, :context_compaction_failed),
    do: Vibe.Event.ContextCompaction.failed(reason)

  defp decode_event_data(data, :subagent_started), do: Vibe.Event.Subagent.started(data)

  defp decode_event_data(data, :subagent_finished), do: Vibe.Event.Subagent.finished(data)

  defp decode_event_data(%{model: model}, :model_selected),
    do: Vibe.Event.Model.selected(model)

  defp decode_event_data(%{effort: effort}, :effort_selected) when is_binary(effort) do
    case Vibe.Model.Effort.from_string(effort) do
      {:ok, effort} -> Vibe.Event.Model.effort_selected(effort)
      {:error, _reason} -> Vibe.Event.Model.effort_selected(effort)
    end
  end

  defp decode_event_data(%{effort: effort}, :effort_selected),
    do: Vibe.Event.Model.effort_selected(effort)

  defp decode_event_data(data, :usage_updated), do: Vibe.Event.Model.usage_updated(data)

  defp decode_event_data(%{status: status}, :status_changed) when is_binary(status),
    do: status |> existing_atom_or_string() |> Vibe.Event.Surface.status_changed()

  defp decode_event_data(%{status: status}, :status_changed),
    do: Vibe.Event.Surface.status_changed(status)

  defp decode_event_data(%{overlay: overlay}, :overlay_opened),
    do: Vibe.Event.Surface.overlay_opened(overlay)

  defp decode_event_data(%{confirmation: confirmation}, :confirmation_requested),
    do: Vibe.Event.Surface.confirmation_requested(confirmation)

  defp decode_event_data(data, :confirmation_requested),
    do: Vibe.Event.Surface.confirmation_requested(data)

  defp decode_event_data(%{key: key, text: text}, :plugin_status_updated),
    do: Vibe.Event.Plugin.status_updated(key, text)

  defp decode_event_data(%{key: key}, :plugin_status_cleared),
    do: Vibe.Event.Plugin.status_cleared(key)

  defp decode_event_data(%{widget: widget}, :plugin_widget_updated),
    do: Vibe.Event.Plugin.widget_updated(widget)

  defp decode_event_data(%{key: key}, :plugin_widget_cleared),
    do: Vibe.Event.Plugin.widget_cleared(key)

  defp decode_event_data(%{message: message}, :working_message_updated),
    do: Vibe.Event.Surface.working_message_updated(message)

  defp decode_event_data(%{label: label}, :hidden_thinking_label_updated),
    do: Vibe.Event.Surface.hidden_thinking_label_updated(label)

  defp decode_event_data(%{title: title}, :title_updated),
    do: Vibe.Event.Surface.title_updated(title)

  defp decode_event_data(%{goal: goal}, :goal_set) do
    goal |> decode_goal() |> Vibe.Event.Goal.set()
  end

  defp decode_event_data(%{goal: goal}, :goal_updated) do
    goal |> decode_goal() |> Vibe.Event.Goal.updated()
  end

  defp decode_event_data(_data, :goal_cleared), do: Vibe.Event.Goal.cleared()

  defp decode_event_data(_data, :goal_continuation_started),
    do: Vibe.Event.Goal.continuation_started()

  defp decode_event_data(%{alert: alert}, :runtime_alert_set) do
    alert |> decode_runtime_alert() |> Vibe.Event.RuntimeAlert.set()
  end

  defp decode_event_data(%{alert: alert}, :runtime_alert_clear) do
    alert |> decode_runtime_alert() |> Vibe.Event.RuntimeAlert.cleared()
  end

  defp decode_event_data(data, _type), do: data

  defp decode_tool_event(data) do
    data
    |> Vibe.Storage.Representation.ToolEvent.decode!()
    |> Vibe.Storage.Restorable.restore()
  end

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

defimpl Vibe.Storage.Persistable, for: Vibe.Event do
  def persist(event) do
    %Vibe.Storage.Representation.Event{
      id: event.id,
      type: event.type,
      session_id: event.session_id,
      at: event.at,
      data: persist_data(event.type, event.data)
    }
  end

  defp persist_data(:tool_started, %Vibe.Event.Tool.Started{event: event}) do
    Vibe.Storage.Persistable.persist(event)
  end

  defp persist_data(:tool_updated, %Vibe.Event.Tool.Updated{event: event}) do
    Vibe.Storage.Persistable.persist(event)
  end

  defp persist_data(:tool_finished, %Vibe.Event.Tool.Finished{event: event}) do
    Vibe.Storage.Persistable.persist(event)
  end

  defp persist_data(:goal_set, %Vibe.Event.Goal.Set{goal: goal}) do
    %{goal: Vibe.Storage.Persistable.persist(goal)}
  end

  defp persist_data(:goal_updated, %Vibe.Event.Goal.Updated{goal: goal}) do
    %{goal: Vibe.Storage.Persistable.persist(goal)}
  end

  defp persist_data(:goal_cleared, %Vibe.Event.Goal.Cleared{}), do: %{}

  defp persist_data(:goal_continuation_started, %Vibe.Event.Goal.ContinuationStarted{}), do: %{}

  defp persist_data(:runtime_alert_set, %Vibe.Event.RuntimeAlert.Set{alert: alert}) do
    %{alert: Vibe.Storage.Persistable.persist(alert)}
  end

  defp persist_data(:runtime_alert_clear, %Vibe.Event.RuntimeAlert.Cleared{alert: alert}) do
    %{alert: Vibe.Storage.Persistable.persist(alert)}
  end

  defp persist_data(:assistant_message_added, data) when is_map(data) do
    data
    |> event_struct_map()
    |> Map.delete(:result)
  end

  defp persist_data(:plugin_widget_updated, %Vibe.Event.Plugin.WidgetUpdated{widget: widget}) do
    %{widget: event_struct_map(widget)}
  end

  defp persist_data(:subagent_finished, %Vibe.Event.Subagent.Finished{} = data) do
    data
    |> Map.from_struct()
    |> Map.drop([:pid])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp persist_data(_type, %struct{} = data) when is_atom(struct), do: event_struct_map(data)

  defp persist_data(_type, data), do: data

  defp event_struct_map(%struct{} = data) when is_atom(struct) do
    data
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp event_struct_map(data) when is_map(data) do
    data
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
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
    |> Vibe.Storage.JSON.value()
    |> Jason.Encode.map(opts)
  end

  defp maybe_put_seq(map, nil), do: map
  defp maybe_put_seq(map, seq), do: Map.put(map, :seq, seq)
end
