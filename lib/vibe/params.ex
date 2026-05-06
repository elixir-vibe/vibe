defmodule Vibe.Params do
  @moduledoc "Shared parameter coercion helpers."
  @spec fetch_required(map(), atom()) :: {:ok, term()} | {:error, String.t()}
  def fetch_required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when value not in [nil, ""] -> {:ok, value}
      _ -> {:error, "missing required parameter: #{key}"}
    end
  end
end
