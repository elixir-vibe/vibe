defprotocol Vibe.Tool.Transport.JSON.Encodable do
  @moduledoc "Protocol for values that cross the model-facing tool JSON boundary."
  @fallback_to_any true

  @spec value(t()) :: term()
  def value(value)
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Any do
  def value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def value(%Date{} = value), do: Date.to_iso8601(value)

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

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.Model.Content.Text do
  def value(content), do: %{type: "text", text: content.text}
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.Model.Content.Image do
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

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.Files.ImageRef do
  def value(ref) do
    ref
    |> Map.from_struct()
    |> Map.delete(:data)
    |> Vibe.Tool.Transport.JSON.Encodable.value()
  end
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.Files.ReadResult do
  def value(result) do
    result
    |> Map.from_struct()
    |> Map.delete(:__content_parts__)
    |> Vibe.Tool.Transport.JSON.Encodable.value()
  end
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: ReqLLM.Message.ContentPart do
  def value(part), do: part |> Map.from_struct() |> Vibe.Tool.Transport.JSON.Encodable.value()
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.Image do
  def value(image), do: image |> Map.from_struct() |> Vibe.Tool.Transport.JSON.Encodable.value()
end

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.UI.Error do
  def value(error), do: error |> Map.from_struct() |> Vibe.Tool.Transport.JSON.Encodable.value()
end
