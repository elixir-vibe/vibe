defimpl Vibe.Storage.JSON.Encodable, for: Vibe.UI.Error do
  def value(error), do: error |> Map.from_struct() |> Vibe.Storage.JSON.value()
end

defimpl Vibe.Storage.JSON.Encodable, for: Vibe.Image do
  def value(image), do: image |> Map.from_struct() |> Vibe.Storage.JSON.value()
end

defimpl Vibe.Storage.JSON.Encodable, for: ReqLLM.Response do
  def value(response) do
    %{
      text: ReqLLM.Response.text(response),
      model: response.model,
      finish_reason: response.finish_reason,
      usage: response.usage,
      provider_meta: response.provider_meta
    }
    |> Vibe.Storage.JSON.value()
  end
end
