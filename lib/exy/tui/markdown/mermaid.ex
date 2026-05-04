defmodule Exy.TUI.Markdown.Mermaid do
  @moduledoc "Mermaid diagram detection and fallback rendering."
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
    {direction, vertices, edges} = DG.Sigil.prepare_gen(source)
    {:ok, direction(direction), vertices, edges}
  rescue
    _ -> :error
  end

  defp direction("LR"), do: :lr
  defp direction("TD"), do: :td
  defp direction("TB"), do: :tb
  defp direction(_direction), do: :td

  defp to_libgraph(vertices, edges) do
    vertices
    |> Enum.reduce(Graph.new(), &add_vertex/2)
    |> add_edges(edges)
  end

  defp add_vertex({:vertex, id}, graph), do: Graph.add_vertex(graph, id)
  defp add_vertex({:vertex, id, label}, graph), do: Graph.add_vertex(graph, id, label: label)

  defp add_edges(graph, edges), do: Enum.reduce(edges, graph, &add_edge/2)

  defp add_edge({:edge, from, to}, graph), do: Graph.add_edge(graph, from, to)

  defp add_edge({:edge, from, to, label}, graph),
    do: Graph.add_edge(graph, from, to, label: label)
end
