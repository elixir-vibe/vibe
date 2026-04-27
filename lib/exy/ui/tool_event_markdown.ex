defimpl Exy.Markdown, for: Exy.UI.ToolEvent do
  def to_markdown(tool) do
    [
      "## Tool ",
      to_string(tool.name || "unknown"),
      "\n\n",
      "- Status: `",
      to_string(tool.status),
      "`\n",
      optional("- ID: `", tool.id, "`\n"),
      section("Arguments", tool.args),
      section("Output", tool.output)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp section(_title, nil), do: []
  defp section(title, value), do: ["\n### ", title, "\n\n", Exy.Markdown.to_markdown(value)]
  defp optional(_prefix, nil, _suffix), do: []
  defp optional(prefix, value, suffix), do: [prefix, to_string(value), suffix]
end
