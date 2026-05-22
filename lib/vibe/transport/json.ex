defmodule Vibe.Transport.JSON do
  @moduledoc "JSON projection for external transport payloads."

  @spec value(term()) :: term()
  def value(term) do
    term
    |> Vibe.Transport.JSON.Encodable.value()
    |> boundary_value()
  end

  defp boundary_value(value), do: value
end
