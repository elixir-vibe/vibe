defprotocol Vibe.Transport.JSON.Encodable do
  @moduledoc "Protocol for values that cross external transport JSON boundaries."
  @fallback_to_any true

  @spec value(t()) :: term()
  def value(value)
end

defimpl Vibe.Transport.JSON.Encodable, for: Any do
  def value(%_{} = value) do
    raise ArgumentError,
          "no transport JSON projection for #{inspect(value.__struct__)}; add a Vibe.Transport.JSON.Encodable implementation"
  end

  def value(value), do: Vibe.Transport.JSON.Value.value(value)
end

defimpl Vibe.Transport.JSON.Encodable, for: List do
  def value(values), do: Enum.map(values, &Vibe.Transport.JSON.Encodable.value/1)
end

defimpl Vibe.Transport.JSON.Encodable, for: Tuple do
  def value(value), do: value |> Tuple.to_list() |> Vibe.Transport.JSON.Encodable.value()
end

defimpl Vibe.Transport.JSON.Encodable, for: Map do
  def value(value) do
    Map.new(value, fn {key, value} ->
      {Vibe.Transport.JSON.Value.key(key), Vibe.Transport.JSON.Encodable.value(value)}
    end)
  end
end
