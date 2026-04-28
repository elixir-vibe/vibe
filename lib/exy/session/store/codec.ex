defmodule Exy.Session.Store.Codec do
  @moduledoc false

  alias Exy.Trajectory
  alias Exy.UI.Event

  @event_types %{
    "assistant_aborted" => :assistant_aborted,
    "assistant_delta" => :assistant_delta,
    "assistant_message_added" => :assistant_message_added,
    "assistant_stream_finished" => :assistant_stream_finished,
    "assistant_stream_started" => :assistant_stream_started,
    "assistant_thinking_delta" => :assistant_thinking_delta,
    "context_compaction_failed" => :context_compaction_failed,
    "context_compaction_finished" => :context_compaction_finished,
    "context_compaction_started" => :context_compaction_started,
    "confirmation_requested" => :confirmation_requested,
    "hidden_thinking_label_updated" => :hidden_thinking_label_updated,
    "messages_cleared" => :messages_cleared,
    "model_selected" => :model_selected,
    "notification_added" => :notification_added,
    "notification_expired" => :notification_expired,
    "overlay_closed" => :overlay_closed,
    "overlay_opened" => :overlay_opened,
    "patch_confirmation_requested" => :patch_confirmation_requested,
    "plugin_status_cleared" => :plugin_status_cleared,
    "plugin_status_updated" => :plugin_status_updated,
    "plugin_widget_cleared" => :plugin_widget_cleared,
    "plugin_widget_updated" => :plugin_widget_updated,
    "prompt_submitted" => :prompt_submitted,
    "selector_closed" => :selector_closed,
    "selector_confirmed" => :selector_confirmed,
    "selector_moved" => :selector_moved,
    "selector_opened" => :selector_opened,
    "session_new_requested" => :session_new_requested,
    "session_selected" => :session_selected,
    "slash_command_submitted" => :slash_command_submitted,
    "status_changed" => :status_changed,
    "subagent_finished" => :subagent_finished,
    "subagent_started" => :subagent_started,
    "title_updated" => :title_updated,
    "tool_finished" => :tool_finished,
    "tool_started" => :tool_started,
    "tool_toggled" => :tool_toggled,
    "truncation_toggled" => :truncation_toggled,
    "usage_updated" => :usage_updated,
    "user_message_added" => :user_message_added,
    "working_message_updated" => :working_message_updated
  }

  @trajectory_types %{
    "assistant_message" => :assistant_message,
    "compaction" => :compaction,
    "llm_usage" => :llm_usage,
    "self_patch_reloaded" => :self_patch_reloaded,
    "subagent_finished" => :subagent_finished,
    "subagent_started" => :subagent_started,
    "tool_call" => :tool_call,
    "user_message" => :user_message
  }

  @spec encode_trajectory(Trajectory.t()) :: map()
  def encode_trajectory(%Trajectory{} = event) do
    %{
      "id" => event.id,
      "session_id" => event.session_id,
      "type" => Atom.to_string(event.type),
      "at" => DateTime.to_iso8601(event.at),
      "data" => json_safe(event.data)
    }
  end

  @spec encode_ui_event(Event.t(), non_neg_integer()) :: map()
  def encode_ui_event(%Event{} = event, seq) do
    %{
      "seq" => seq,
      "id" => event.id,
      "session_id" => event.session_id,
      "type" => Atom.to_string(event.type),
      "at" => DateTime.to_iso8601(event.at),
      "data" => json_safe(event.data)
    }
  end

  @spec eval_state_entry(String.t(), Code.binding(), Macro.Env.t()) ::
          {:ok, map()} | {:error, term()}
  def eval_state_entry(session_id, binding, env) do
    snapshot = %{binding: binding, env: env}

    {:ok,
     %{
       "entry_type" => "eval_state",
       "session_id" => session_id,
       "at" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "state" => :erlang.term_to_binary(snapshot)
     }}
  rescue
    exception -> {:error, exception}
  end

  @spec decode_eval_state_binary(binary()) ::
          {:ok, %{binding: Code.binding(), env: Macro.Env.t()}} | :error
  def decode_eval_state_binary(binary) when is_binary(binary), do: decode_eval_state(binary)

  @spec decode_eval_state_line(String.t(), term()) ::
          %{binding: Code.binding(), env: Macro.Env.t()} | term()
  def decode_eval_state_line(line, acc) do
    with {:ok, %{"entry_type" => "eval_state", "state" => encoded}} <- Jason.decode(line),
         {:ok, state} <- decode_eval_state(encoded) do
      state
    else
      _ -> acc
    end
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

  defp decode_eval_state(encoded) do
    with binary when is_binary(binary) <- maybe_base64_decode(encoded),
         %{binding: binding, env: %Macro.Env{} = env} <- :erlang.binary_to_term(binary, [:safe]) do
      {:ok, %{binding: binding, env: env}}
    else
      _ -> :error
    end
  rescue
    _exception -> :error
  end

  defp maybe_base64_decode(encoded) when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, binary} -> binary
      :error -> encoded
    end
  end

  defp decode_ui_event(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]),
         {:ok, type} <- decode_event_type(map["type"]) do
      data = map |> Map.get("data", %{}) |> atomize() |> decode_ui_event_data(type)

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
       Trajectory.new(type, atomize(map["data"] || %{}),
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
      if Map.has_key?(data, :error),
        do: %{error: Map.get(data, :error)},
        else: %{result: Map.get(data, :result) || data}

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
       when type in [:tool_started, :tool_finished] and is_map(data) do
    struct(
      Exy.UI.ToolEvent,
      Map.take(data, [:id, :name, :args, :output, :output_format, :output_parts, :status])
    )
  end

  defp decode_ui_event_data(data, _type), do: data

  defp decode_event_type(type) when is_binary(type), do: Map.fetch(@event_types, type)
  defp decode_event_type(_type), do: :error

  defp decode_trajectory_type(type) when is_binary(type), do: Map.fetch(@trajectory_types, type)
  defp decode_trajectory_type(_type), do: :error

  defp json_safe(value) when is_atom(value), do: %{"$atom" => Atom.to_string(value)}

  defp json_safe(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {to_string(key), json_safe(value)} end)
  rescue
    _exception -> inspect(value, limit: 50)
  end

  defp json_safe(value), do: inspect(value, limit: 50)

  defp atomize(%{"$atom" => value}) when is_binary(value) do
    case safe_existing_atom(value) do
      {:ok, atom} -> atom
      :error -> value
    end
  end

  defp atomize(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {atomize_key(key), atomize(value)} end)
  end

  defp atomize(list) when is_list(list), do: Enum.map(list, &atomize/1)
  defp atomize(value), do: value

  defp atomize_key(key) when is_binary(key) do
    case safe_existing_atom(key) do
      {:ok, atom} -> atom
      :error -> key
    end
  end

  defp atomize_key(key), do: key

  defp safe_existing_atom(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end
end
