defimpl Vibe.Tool.Transport.JSON.Encodable, for: Vibe.UI.Error do
  def value(error), do: error |> Map.from_struct() |> Vibe.Tool.Transport.JSON.Encodable.value()
end
