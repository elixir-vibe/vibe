defimpl Exy.Markdown, for: Exy.Image do
  def to_markdown(image) do
    alt = image.filename || "image"
    details = [image.mime_type, dimensions(image)] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

    [
      "![#{alt}](#{Exy.Image.data_uri(image)})",
      "",
      if(details == "", do: nil, else: "`#{details}`")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp dimensions(%{width: width, height: height}) when is_integer(width) and is_integer(height),
    do: "#{width}x#{height}"

  defp dimensions(_image), do: nil
end
