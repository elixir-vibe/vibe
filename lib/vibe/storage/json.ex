defmodule Vibe.Storage.JSON do
  @moduledoc "JSON projection for storage representation values."

  @spec value(term()) :: term()
  def value(term) do
    term
    |> Vibe.Storage.JSON.Encodable.value()
    |> boundary_value()
  end

  defp boundary_value(value), do: value

  @spec key(term()) :: String.t()
  def key(term) when is_atom(term), do: Atom.to_string(term)
  def key(term) when is_binary(term), do: term
  def key(term), do: to_string(term)
end
