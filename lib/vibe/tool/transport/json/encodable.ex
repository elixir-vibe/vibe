defprotocol Vibe.Tool.Transport.JSON.Encodable do
  @moduledoc "Protocol for values that cross the model-facing tool JSON boundary."
  @fallback_to_any true

  @spec value(t()) :: term()
  def value(value)
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Any do
  def value(%_{} = value) do
    raise ArgumentError,
          "no tool transport JSON projection for #{inspect(value.__struct__)}; add a Vibe.Tool.Transport.JSON.Encodable implementation"
  end

  def value(value), do: Vibe.Tool.Transport.JSON.Value.value(value)
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: List do
  def value(values), do: Enum.map(values, &Vibe.Tool.Transport.JSON.Encodable.value/1)
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Tuple do
  def value(value), do: value |> Tuple.to_list() |> Vibe.Tool.Transport.JSON.Encodable.value()
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Map do
  def value(value) do
    Map.new(value, fn {key, value} ->
      {Vibe.Tool.Transport.JSON.Value.key(key), Vibe.Tool.Transport.JSON.Encodable.value(value)}
    end)
  end
end
