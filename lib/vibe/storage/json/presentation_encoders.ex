defimpl Vibe.Storage.JSON.Encodable, for: Vibe.Presentation.Widget do
  def value(widget), do: widget |> Map.from_struct() |> Vibe.Storage.JSON.Encodable.value()
end
