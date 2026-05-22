defimpl Vibe.Storage.JSON.Encodable, for: Vibe.UI.Error do
  def value(error), do: error |> Map.from_struct() |> Vibe.Storage.JSON.Encodable.value()
end

defimpl Vibe.Storage.JSON.Encodable, for: Vibe.UI.Selector do
  def value(selector), do: selector |> Map.from_struct() |> Vibe.Storage.JSON.Encodable.value()
end
