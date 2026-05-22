defprotocol Vibe.Storage.JSON.Encodable do
  @moduledoc "Protocol for values that explicitly cross the storage JSON boundary."
  @fallback_to_any true

  @spec value(t()) :: term()
  def value(value)
end

defimpl Vibe.Storage.JSON.Encodable, for: Any do
  def value(value) when is_boolean(value) or is_nil(value), do: value
  def value(value) when is_atom(value), do: Atom.to_string(value)

  def value(%_{} = value) do
    raise ArgumentError,
          "no storage JSON projection for #{inspect(value.__struct__)}; add a Vibe.Storage.JSON.Encodable implementation"
  end

  def value(value) when is_binary(value) do
    if String.valid?(value), do: value, else: %{type: "binary", data: Base.encode64(value)}
  end

  def value(value) when is_number(value), do: value

  def value(value) do
    raise ArgumentError,
          "no storage JSON projection for #{inspect(value)}; add a Vibe.Storage.JSON.Encodable implementation"
  end
end

defimpl Vibe.Storage.JSON.Encodable, for: List do
  def value(values), do: Enum.map(values, &Vibe.Storage.JSON.Encodable.value/1)
end

defimpl Vibe.Storage.JSON.Encodable, for: Tuple do
  def value(value), do: value |> Tuple.to_list() |> Vibe.Storage.JSON.Encodable.value()
end

defimpl Vibe.Storage.JSON.Encodable, for: Map do
  def value(value) do
    Map.new(value, fn {key, value} ->
      {Vibe.Storage.JSON.Value.key(key), Vibe.Storage.JSON.Encodable.value(value)}
    end)
  end
end
