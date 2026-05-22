defimpl Vibe.Presentation.Markdown.Renderable, for: Vibe.Presentation.Tool do
  def render(tool) do
    [
      "## Tool ",
      to_string(tool.name || "unknown"),
      "\n\n",
      "- Status: `",
      to_string(tool.status),
      "`\n",
      meta(tool.meta),
      blocks(tool.body)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp meta([]), do: []
  defp meta(values), do: Enum.map(values, &["- ", to_string(&1), "\n"])

  defp blocks([]), do: []

  defp blocks(blocks) do
    Enum.map(blocks, fn
      {:text, value, _opts} -> section("Text", value)
      {:inspect, value, _opts} -> section("Value", value)
      {:markdown, value, _opts} -> section("Markdown", value)
      {:source, value, _opts} -> section("Source", value)
      {:error, value, _opts} -> section("Error", value)
      {:diff, value, _opts} -> section("Diff", value)
      {:lines, lines, _opts} -> section("Lines", Enum.join(lines, "\n"))
      {:image, image, _opts} -> section("Image", Vibe.Markdown.to_markdown(image))
      {:image_ref, image, _opts} -> section("Image", Vibe.Markdown.to_markdown(image))
      other -> section("Value", inspect(other, pretty: true))
    end)
  end

  defp section(_title, nil), do: []
  defp section(title, value), do: ["\n### ", title, "\n\n", to_string(value)]
end
