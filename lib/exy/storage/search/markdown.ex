defimpl Exy.Markdown, for: Exy.Storage.Search.Result do
  @moduledoc """
  Markdown rendering for durable storage search hits.
  """

  def to_markdown(result) do
    [
      "### ",
      title(result),
      "\n\n",
      "- Source: `",
      to_string(result.source),
      "`\n",
      optional("- Owner: `", result.owner_id, "`\n"),
      optional("- At: `", format_datetime(result.at), "`\n"),
      optional("- Rank: `", result.rank, "`\n"),
      "\n",
      result.snippet || result.text || ""
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp title(%{title: title}) when is_binary(title) and title != "", do: title
  defp title(%{owner_id: owner_id}) when is_binary(owner_id), do: owner_id
  defp title(result), do: to_string(result.id)
  defp optional(_prefix, nil, _suffix), do: []
  defp optional(_prefix, "", _suffix), do: []
  defp optional(prefix, value, suffix), do: [prefix, to_string(value), suffix]
  defp format_datetime(%DateTime{} = at), do: DateTime.to_iso8601(at)
  defp format_datetime(value), do: value
end
