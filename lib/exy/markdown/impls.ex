defimpl Exy.Markdown, for: Any do
  def to_markdown(%{__struct__: module} = term) do
    if function_exported?(module, :to_markdown, 1) do
      module.to_markdown(term)
    else
      inspect(term, pretty: true, limit: 50)
    end
  end

  def to_markdown(term), do: inspect(term, pretty: true, limit: 50)
end

defimpl Exy.Markdown, for: BitString do
  def to_markdown(text), do: text
end

defimpl Exy.Markdown, for: Atom do
  def to_markdown(atom), do: "`#{inspect(atom)}`"
end

defimpl Exy.Markdown, for: Integer do
  def to_markdown(integer), do: to_string(integer)
end

defimpl Exy.Markdown, for: Float do
  def to_markdown(float), do: to_string(float)
end

defimpl Exy.Markdown, for: Tuple do
  def to_markdown(tuple), do: tuple |> Tuple.to_list() |> Exy.Markdown.to_markdown()
end

defimpl Exy.Markdown, for: List do
  def to_markdown([]), do: ""

  def to_markdown(list) do
    if keyword_rows?(list) do
      Enum.map_join(list, "\n", fn {key, value} -> "- #{key}: #{inline(value)}" end)
    else
      Enum.map_join(list, "\n", &list_item/1)
    end
  end

  defp keyword_rows?(list), do: Keyword.keyword?(list)

  defp list_item(value) do
    value
    |> Exy.Markdown.to_markdown()
    |> String.split("\n")
    |> case do
      [single] -> "- " <> single
      [first | rest] -> Enum.map_join([first | rest], "\n", &list_line/1)
      [] -> "-"
    end
  end

  defp list_line(line), do: "- " <> line

  defp inline(value) do
    value
    |> Exy.Markdown.to_markdown()
    |> String.replace("\n", " ")
  end
end

defimpl Exy.Markdown, for: Map do
  def to_markdown(map) do
    map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map_join("\n", fn {key, value} -> "- #{key}: #{inline(value)}" end)
  end

  defp inline(value) do
    value
    |> Exy.Markdown.to_markdown()
    |> String.replace("\n", " ")
  end
end

defimpl Exy.Markdown, for: Exy.Command.Result do
  def to_markdown(result) do
    [
      "## Command ",
      to_string(result.status),
      "\n\n",
      "- Command: `",
      Enum.join(result.argv, " "),
      "`\n",
      "- CWD: `",
      result.cwd,
      "`\n",
      "- Exit status: `",
      inspect(result.exit_status),
      "`\n",
      "- Duration: `",
      to_string(result.duration_ms),
      "ms`\n",
      "- Log: `",
      result.output_path,
      "`\n\n",
      "```text\n",
      String.trim_trailing(result.output),
      "\n```"
    ]
    |> IO.iodata_to_binary()
  end
end
