defmodule Vibe.CLI.Commands.Connect.KnownNodesView do
  @moduledoc false

  @spec render([map()]) :: String.t()
  def render([]) do
    "No known nodes. Usage: vibe connect --ssh host:port | vibe connect --dist node@host"
  end

  def render(nodes) do
    nodes
    |> Enum.map(&node_line/1)
    |> then(&Enum.join(["Known nodes:" | &1], "\n"))
  end

  defp node_line(entry) do
    label = if entry["label"], do: " (#{entry["label"]})", else: ""
    transport = entry["transport"] || "distribution"
    "  #{entry["node"]} [#{transport}]#{label}"
  end
end
