defmodule Vibe.Storage.JSON do
  @moduledoc "JSON projection for storage representation values."

  @spec value(term()) :: term()
  def value(term) do
    term
    |> Vibe.Storage.JSON.Encodable.value()
    |> boundary_value()
  end

  @doc "Intentional storage JSON key boundary."
  @spec key(term()) :: String.t()
  defdelegate key(term), to: Vibe.Storage.JSON.Value

  defp boundary_value(value), do: value
end
