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

defimpl Vibe.Tool.Transport.JSON.Encodable, for: ReqLLM.Message.ContentPart do
  def value(part), do: part |> Map.from_struct() |> Vibe.Tool.Transport.JSON.Encodable.value()
end
