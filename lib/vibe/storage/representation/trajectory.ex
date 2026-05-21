defmodule Vibe.Storage.Representation.Trajectory do
  @moduledoc "Storage representation and event projection for trajectory entries."

  alias Vibe.Event
  alias Vibe.Trajectory

  @json_atom_keys MapSet.new([
                    "data",
                    "error",
                    "id",
                    "input_tokens",
                    "output_tokens",
                    "prompt",
                    "result",
                    "session_id",
                    "total_cost",
                    "total_tokens",
                    "type",
                    "usage"
                  ])

  @spec encode(Trajectory.t()) :: map()
  def encode(%Trajectory{} = event) do
    event
    |> Jason.encode!()
    |> Jason.decode!()
  end

  @spec decode_map(map()) :: {:ok, Trajectory.t()} | :error
  def decode_map(map) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(map["at"]),
         {:ok, type} <- decode_existing_atom(map["type"]) do
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

  @spec decode_line(String.t()) :: [Trajectory.t()]
  def decode_line(line) do
    with {:ok, map} <- Jason.decode(line),
         true <- Map.get(map, "entry_type", "trajectory") == "trajectory",
         {:ok, event} <- decode_map(map) do
      [event]
    else
      _ -> []
    end
  end

  @spec project_events([Trajectory.t()]) :: [{pos_integer(), Event.t()}]
  def project_events(events) do
    events
    |> Enum.flat_map(&project_event/1)
    |> Enum.with_index(1)
    |> Enum.map(fn {event, seq} -> {seq, event} end)
  end

  defp project_event(%Trajectory{
         type: :user_message,
         session_id: session_id,
         at: at,
         data: data
       }) do
    text = Map.get(data, :prompt, "")
    [Event.new(:user_message_added, session_id, %{text: text}, at: at)]
  end

  defp project_event(%Trajectory{
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

  defp project_event(%Trajectory{
         type: :llm_usage,
         session_id: session_id,
         at: at,
         data: data
       }) do
    [Event.new(:usage_updated, session_id, data, at: at)]
  end

  defp project_event(_event), do: []

  defp decode_existing_atom(type) when is_binary(type) do
    {:ok, String.to_existing_atom(type)}
  rescue
    ArgumentError -> :error
  end

  defp decode_existing_atom(_type), do: :error

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      atom_key = atomize_key(key)
      {atom_key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value

  defp atomize_key(key) when is_binary(key) do
    if MapSet.member?(@json_atom_keys, key), do: String.to_existing_atom(key), else: key
  end

  defp atomize_key(key), do: key
end
