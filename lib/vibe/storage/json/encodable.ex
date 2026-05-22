defprotocol Vibe.Storage.JSON.Encodable do
  @moduledoc "Protocol for values that explicitly cross the storage JSON boundary."
  @fallback_to_any true

  @spec value(t()) :: term()
  def value(value)
end

defimpl Vibe.Storage.JSON.Encodable, for: Any do
  def value(value) when is_boolean(value) or is_nil(value), do: value
  def value(value) when is_atom(value), do: Atom.to_string(value)
  def value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def value(%Date{} = value), do: Date.to_iso8601(value)

  def value(%_{} = value) do
    raise ArgumentError,
          "no storage JSON projection for #{inspect(value.__struct__)}; add a Vibe.Storage.JSON.Encodable implementation"
  end

  def value(value) when is_binary(value) do
    if String.valid?(value), do: value, else: %{type: "binary", data: Base.encode64(value)}
  end

  def value(value) when is_number(value), do: value

  def value(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Vibe.Storage.JSON.Value.value()

  def value(value) when is_list(value), do: Enum.map(value, &Vibe.Storage.JSON.Value.value/1)

  def value(value) when is_map(value) do
    Map.new(value, fn {key, value} ->
      {Vibe.Storage.JSON.Value.key(key), Vibe.Storage.JSON.Value.value(value)}
    end)
  end

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

defimpl Vibe.Storage.JSON.Encodable, for: Vibe.Model.Content.Text do
  def value(content), do: %{type: "text", text: content.text}
end

defimpl Vibe.Storage.JSON.Encodable, for: Vibe.Model.Content.Image do
  def value(content) do
    %{
      type: "image",
      data: content.data,
      mime_type: content.mime_type,
      filename: content.filename,
      width: content.width,
      height: content.height
    }
  end
end

defimpl Vibe.Storage.JSON.Encodable, for: Vibe.Files.ImageRef do
  def value(ref) do
    ref
    |> Map.from_struct()
    |> Map.delete(:data)
    |> Vibe.Storage.JSON.Encodable.value()
  end
end

defimpl Vibe.Storage.JSON.Encodable, for: Vibe.Files.ReadResult do
  def value(result) do
    result
    |> Map.from_struct()
    |> Map.delete(:__content_parts__)
    |> Vibe.Storage.JSON.Encodable.value()
  end
end
