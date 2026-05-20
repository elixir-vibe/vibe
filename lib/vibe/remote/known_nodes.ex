defmodule Vibe.Remote.KnownNodes do
  @moduledoc """
  Persisted trusted remote endpoints at `~/.vibe/known-nodes.json`.
  """

  @spec path() :: String.t()
  def path, do: Path.join(Vibe.Paths.home(), "known-nodes.json")

  @spec list() :: [map()]
  def list do
    case File.read(path()) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, nodes} when is_list(nodes) -> nodes
          _error -> []
        end

      {:error, :enoent} ->
        []

      _error ->
        []
    end
  end

  @spec add(String.t(), keyword()) :: :ok
  def add(node_name, opts \\ []) do
    entry = %{
      "node" => node_name,
      "added_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "label" => Keyword.get(opts, :label),
      "transport" => Keyword.get(opts, :transport, "distribution")
    }

    nodes =
      list()
      |> Enum.reject(&(&1["node"] == node_name))
      |> Kernel.++([entry])

    write!(nodes)
  end

  @spec remove(String.t()) :: :ok
  def remove(node_name) do
    list()
    |> Enum.reject(&(&1["node"] == node_name))
    |> write!()
  end

  defp write!(nodes) do
    File.mkdir_p!(Path.dirname(path()))
    File.write!(path(), Jason.encode!(nodes, pretty: true))
  end
end
