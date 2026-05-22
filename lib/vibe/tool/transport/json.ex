defmodule Vibe.Tool.Transport.JSON do
  @moduledoc "JSON projection for model-facing tool transport payloads."

  @spec value(term()) :: term()
  def value(term) do
    term
    |> Vibe.Tool.Transport.JSON.Encodable.value()
    |> boundary_value()
  end

  defp boundary_value(value), do: value
end
