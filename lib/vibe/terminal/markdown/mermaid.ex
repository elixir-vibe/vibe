defmodule Vibe.Terminal.Markdown.Mermaid do
  @moduledoc "Mermaid diagram detection and fallback rendering."

  @edge_with_label ~r/^\s*(.+?)\s+--\s+(.+?)\s+-->\s+(.+?)\s*$/
  @edge ~r/^\s*(.+?)\s*--?>\s*(.+?)\s*$/
  @node ~r/^\s*([A-Za-z0-9_.:-]+)(?:\[([^\]]+)\]|\(([^\)]+)\)|\{([^\}]+)\})?\s*$/

  @spec render(String.t(), pos_integer()) :: {:ok, [String.t()]} | :error
  def render(source, width) when is_binary(source) and is_integer(width) do
    with {:ok, direction, vertices, edges} <- parse(source),
         graph <- to_libgraph(vertices, edges) do
      lines =
        :erlang.apply(Boxart, :render, [
          graph,
          [direction: direction, max_width: width, max_label_width: max(width - 8, 12)]
        ])
        |> String.split("\n", trim: true)

      if lines == [], do: :error, else: {:ok, lines}
    end
  rescue
    _ -> :error
  end

  defp parse(source) do
    source
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "%%")))
    |> case do
      [header | statements] -> parse_statements(header, statements)
      [] -> :error
    end
  end

  defp parse_statements(header, statements) do
    with {:ok, direction} <- parse_direction(header) do
      {vertices, edges} = Enum.reduce(statements, {%{}, []}, &parse_statement/2)
      {:ok, direction, Map.values(vertices), Enum.reverse(edges)}
    end
  end

  defp parse_direction(header) do
    case String.split(header) do
      [kind, dir | _] when kind in ["graph", "flowchart"] -> {:ok, direction(dir)}
      _other -> :error
    end
  end

  defp parse_statement(statement, {vertices, edges}) do
    cond do
      captures = Regex.run(@edge_with_label, statement, capture: :all_but_first) ->
        [from, label, to] = captures
        {from_node, vertices} = put_node(vertices, from)
        {to_node, vertices} = put_node(vertices, to)
        {vertices, [{:edge, from_node, to_node, String.trim(label)} | edges]}

      captures = Regex.run(@edge, statement, capture: :all_but_first) ->
        [from, to] = captures
        {from_node, vertices} = put_node(vertices, from)
        {to_node, vertices} = put_node(vertices, to)
        {vertices, [{:edge, from_node, to_node} | edges]}

      true ->
        {_node, vertices} = put_node(vertices, statement)
        {vertices, edges}
    end
  end

  defp put_node(vertices, source) do
    {id, label} = parse_node(source)
    vertices = Map.put_new(vertices, id, {:vertex, id, label})
    {id, vertices}
  end

  defp parse_node(source) do
    source = String.trim(source)

    case Regex.run(@node, source, capture: :all_but_first) do
      [id, label] -> {id, label}
      [id, label, ""] -> {id, label}
      [id, "", label] -> {id, label}
      [id, "", "", label] -> {id, label}
      [id | labels] -> {id, Enum.find(labels, id, &(&1 != ""))}
      _other -> {source, source}
    end
  end

  defp direction("LR"), do: :lr
  defp direction("RL"), do: :rl
  defp direction("TD"), do: :td
  defp direction("TB"), do: :tb
  defp direction("BT"), do: :bt
  defp direction(_direction), do: :td

  defp to_libgraph(vertices, edges) do
    vertices
    |> Enum.reduce(Graph.new(), &add_vertex/2)
    |> add_edges(edges)
  end

  defp add_vertex({:vertex, id, label}, graph), do: Graph.add_vertex(graph, id, label: label)

  defp add_edges(graph, edges), do: Enum.reduce(edges, graph, &add_edge/2)

  defp add_edge({:edge, from, to}, graph), do: Graph.add_edge(graph, from, to)

  defp add_edge({:edge, from, to, label}, graph),
    do: Graph.add_edge(graph, from, to, label: label)
end
