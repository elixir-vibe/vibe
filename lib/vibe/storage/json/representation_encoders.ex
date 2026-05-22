defimpl Vibe.Storage.JSON.Encodable,
  for: [
    Vibe.Storage.Representation.Event,
    Vibe.Storage.Representation.Goal,
    Vibe.Storage.Representation.RuntimeAlert,
    Vibe.Storage.Representation.ToolEvent
  ] do
  def value(representation) do
    representation
    |> Map.from_struct()
    |> Vibe.Storage.JSON.Encodable.value()
  end
end
