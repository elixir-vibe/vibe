defmodule Vibe.Storage.Representation.RuntimeAlert do
  @moduledoc "Current storage representation for `Vibe.SystemAlarms.Alert`."

  @enforce_keys [:id, :source, :type, :severity, :at]
  defstruct [:id, :source, :type, :severity, :detail, :at, context: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          source: atom(),
          type: atom(),
          severity: Vibe.SystemAlarms.Alert.severity(),
          detail: String.t() | nil,
          at: DateTime.t(),
          context: map()
        }

  @spec decode!(map()) :: t()
  def decode!(map) when is_map(map) do
    map = atomize_known_keys(map)

    %__MODULE__{
      id: Map.fetch!(map, :id),
      source: map |> Map.fetch!(:source) |> decode_atom!(),
      type: map |> Map.fetch!(:type) |> decode_atom!(),
      severity: map |> Map.fetch!(:severity) |> decode_atom!(),
      detail: Map.get(map, :detail),
      at: map |> Map.fetch!(:at) |> decode_datetime!(),
      context: decode_context!(Map.get(map, :context, %{}))
    }
  end

  defp atomize_known_keys(map) do
    Map.new(map, fn
      {key, value} when key in ["id", "source", "type", "severity", "detail", "at", "context"] ->
        {String.to_existing_atom(key), value}

      entry ->
        entry
    end)
  end

  defp decode_context!(context) when is_map(context) do
    Map.new(context, fn {key, value} -> {decode_atom!(key), value} end)
  end

  defp decode_context!(_context), do: %{}

  defp decode_datetime!(%DateTime{} = datetime), do: datetime

  defp decode_datetime!(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _error -> raise ArgumentError, "invalid runtime alert datetime: #{inspect(value)}"
    end
  end

  defp decode_atom!(value) when is_atom(value), do: value
  defp decode_atom!(value) when is_binary(value), do: String.to_existing_atom(value)
end

defimpl Vibe.Storage.Persistable, for: Vibe.SystemAlarms.Alert do
  def persist(alert) do
    %Vibe.Storage.Representation.RuntimeAlert{
      id: alert.id,
      source: alert.source,
      type: alert.type,
      severity: alert.severity,
      detail: alert.detail,
      at: alert.at,
      context: alert.context
    }
  end
end

defimpl Vibe.Storage.Restorable, for: Vibe.Storage.Representation.RuntimeAlert do
  def restore(alert) do
    %Vibe.SystemAlarms.Alert{
      id: alert.id,
      source: alert.source,
      type: alert.type,
      severity: alert.severity,
      detail: alert.detail,
      at: alert.at,
      context: alert.context
    }
  end
end

defimpl Jason.Encoder, for: Vibe.Storage.Representation.RuntimeAlert do
  def encode(alert, opts) do
    alert
    |> Map.from_struct()
    |> Vibe.Storage.JSON.value()
    |> Jason.Encode.map(opts)
  end
end
