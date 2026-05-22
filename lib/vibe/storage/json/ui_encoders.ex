defimpl Vibe.Storage.JSON.Encodable, for: Vibe.UI.Selector do
  def value(selector), do: selector |> Map.from_struct() |> Vibe.Storage.JSON.value()
end

defimpl Vibe.Storage.JSON.Encodable, for: Vibe.Presentation.Widget do
  def value(widget), do: widget |> Map.from_struct() |> Vibe.Storage.JSON.value()
end
