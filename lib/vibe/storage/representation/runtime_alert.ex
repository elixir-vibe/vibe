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
  def decode!(
        %{"id" => id, "source" => source, "type" => type, "severity" => severity, "at" => at} =
          map
      ) do
    %__MODULE__{
      id: id,
      source: decode_atom!(source),
      type: decode_atom!(type),
      severity: decode_atom!(severity),
      detail: Map.get(map, "detail"),
      at: decode_datetime!(at),
      context: decode_context!(Map.get(map, "context", %{}))
    }
  end

  def decode!(%{id: id, source: source, type: type, severity: severity, at: at} = map) do
    %__MODULE__{
      id: id,
      source: decode_atom!(source),
      type: decode_atom!(type),
      severity: decode_atom!(severity),
      detail: Map.get(map, :detail),
      at: decode_datetime!(at),
      context: decode_context!(Map.get(map, :context, %{}))
    }
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
