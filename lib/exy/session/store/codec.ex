defmodule Exy.Session.Store.Codec do
  @moduledoc "Internal implementation module."
  alias Exy.Trajectory
  alias Exy.UI.Event

  @spec encode_trajectory(Trajectory.t()) :: map()
  def encode_trajectory(%Trajectory{} = event) do
    event
    |> Jason.encode!()
    |> Jason.decode!()
  end

  @spec encode_ui_event(Event.t(), non_neg_integer()) :: map()
  def encode_ui_event(%Event{} = event, seq) do
    event
    |> Jason.encode!()
    |> Jason.decode!()
    |> Map.put("seq", seq)
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
       when type in [:tool_started, :tool_updated, :tool_finished] and is_map(data) do
    tool_data =
      data
      |> Map.take([:id, :name, :args, :output, :output_format, :output_parts, :status, :phase])
      |> decode_tool_content_parts()

    struct(Exy.UI.ToolEvent, tool_data)
  end

  defp decode_ui_event_data(%{effort: effort} = data, :effort_selected) when is_binary(effort) do
    case Exy.Model.Effort.from_string(effort) do
      {:ok, effort} -> %{data | effort: effort}
      {:error, _reason} -> data
    end
  end

  defp decode_ui_event_data(%{status: status} = data, :status_changed) when is_binary(status),
    do: %{data | status: existing_atom_or_string(status)}

  defp decode_ui_event_data(%{level: level} = data, :notification_added) when is_binary(level),
    do: %{data | level: existing_atom_or_string(level)}

  defp decode_ui_event_data(data, _type), do: data

  defp decode_tool_content_parts(%{output: output} = data) when is_map(output),
    do: %{data | output: decode_tool_output_content_parts(output)}

  defp decode_tool_content_parts(data), do: data

  defp decode_tool_output_content_parts(%{parts: parts} = output) when is_list(parts),
    do: %{output | parts: Enum.map(parts, &decode_content_part/1)}

  defp decode_tool_output_content_parts(output), do: output

  defp decode_content_part(%{type: "text", text: text}) when is_binary(text),
    do: Exy.Model.Content.text(text)

  defp decode_content_part(%{type: :text, text: text}) when is_binary(text),
    do: Exy.Model.Content.text(text)

  defp decode_content_part(%{type: "image", data: data, mime_type: mime_type} = part)
       when is_binary(data) and is_binary(mime_type) do
    Exy.Model.Content.image(
      data: data,
      mime_type: mime_type,
      filename: Map.get(part, :filename),
      width: Map.get(part, :width),
      height: Map.get(part, :height)
    )
  end

  defp decode_content_part(%{type: :image, data: data, mime_type: mime_type} = part)
       when is_binary(data) and is_binary(mime_type) do
    Exy.Model.Content.image(
      data: data,
      mime_type: mime_type,
      filename: Map.get(part, :filename),
      width: Map.get(part, :width),
      height: Map.get(part, :height)
    )
  end

  defp decode_content_part(part), do: part

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

  defp atomize_key(key) when is_binary(key), do: existing_atom_or_string(key)
  defp atomize_key(key), do: key

  defp existing_atom_or_string(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end
end
