defimpl Vibe.Markdown, for: Vibe.UI.ToolEvent do
  @moduledoc """
  Markdown rendering for semantic tool lifecycle events.
  """

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
  defp section(title, value), do: ["\n### ", title, "\n\n", Vibe.Markdown.to_markdown(value)]
  defp optional(_prefix, nil, _suffix), do: []
  defp optional(prefix, value, suffix), do: [prefix, to_string(value), suffix]
end
