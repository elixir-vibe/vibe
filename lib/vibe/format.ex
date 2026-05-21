defmodule Vibe.Format do
  @moduledoc "Shared human-readable formatting helpers."

  @spec bytes(non_neg_integer()) :: String.t()
  def bytes(bytes) when bytes >= 1_000_000, do: "#{Float.round(bytes / 1_000_000, 1)} MB"
  def bytes(bytes) when bytes >= 1_000, do: "#{Float.round(bytes / 1_000, 1)} KB"
  def bytes(bytes), do: "#{bytes} B"
end
