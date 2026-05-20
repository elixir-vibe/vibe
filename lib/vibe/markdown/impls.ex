defimpl Vibe.Markdown, for: Any do
  @moduledoc """
  Fallback Markdown rendering for terms without a dedicated protocol impl.
  """

  def to_markdown(%{__struct__: module} = term) do
    if function_exported?(module, :to_markdown, 1) do
      module.to_markdown(term)
    else
      inspect(term, pretty: true, limit: 50)
    end
  end

  def to_markdown(term), do: inspect(term, pretty: true, limit: 50)
end

defimpl Vibe.Markdown, for: BitString do
  @moduledoc """
  Markdown rendering for strings and binaries.
  """

  def to_markdown(text), do: text
end

defimpl Vibe.Markdown, for: Atom do
  @moduledoc """
  Markdown rendering for atoms.
  """

  def to_markdown(atom), do: "`#{inspect(atom)}`"
end

defimpl Vibe.Markdown, for: Integer do
  @moduledoc """
  Markdown rendering for integers.
  """

  def to_markdown(integer), do: to_string(integer)
end

defimpl Vibe.Markdown, for: Float do
  @moduledoc """
  Markdown rendering for floats.
  """

  def to_markdown(float), do: to_string(float)
end

defimpl Vibe.Markdown, for: Tuple do
  def to_markdown(tuple), do: tuple |> Tuple.to_list() |> Vibe.Markdown.to_markdown()
end

defimpl Vibe.Markdown, for: List do
  @moduledoc """
  Markdown rendering for lists as bullet lists.
  """

  def to_markdown([]), do: ""

  def to_markdown(list) do
    if keyword_rows?(list) do
      list
      |> Enum.map(fn {key, value} -> ["- ", to_string(key), ": ", inline(value)] end)
      |> join_lines()
    else
      list |> Enum.map(&list_item/1) |> join_lines()
    end
  end

  defp keyword_rows?(list), do: Keyword.keyword?(list)

  defp list_item(value) do
    value
    |> Vibe.Markdown.to_markdown()
    |> String.split("\n")
    |> case do
      [single] -> "- " <> single
      [first | rest] -> [first | rest] |> Enum.map(&list_line/1) |> join_lines()
      [] -> "-"
    end
  end

  defp list_line(line), do: ["- ", line]

  defp join_lines(lines), do: lines |> Enum.intersperse("\n") |> IO.iodata_to_binary()

  defp inline(value) do
    value
    |> Vibe.Markdown.to_markdown()
    |> String.replace("\n", " ")
  end
end

defimpl Vibe.Markdown, for: Map do
  @moduledoc """
  Markdown rendering for maps.
  """

  def to_markdown(map) do
    map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> ["- ", to_string(key), ": ", inline(value)] end)
    |> Enum.intersperse("\n")
    |> IO.iodata_to_binary()
  end

  defp inline(value) do
    value
    |> Vibe.Markdown.to_markdown()
    |> String.replace("\n", " ")
  end
end
