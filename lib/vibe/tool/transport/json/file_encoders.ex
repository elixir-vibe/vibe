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

defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.Image do
  def value(image), do: image |> Map.from_struct() |> Vibe.Tool.Transport.JSON.Encodable.value()
end
