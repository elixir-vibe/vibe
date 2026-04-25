defmodule Exy.Session.Preview do
  @moduledoc false

  @spec message(map() | nil) :: String.t()
  def message(nil), do: ""

  def message(message) when is_map(message) do
    message
    |> preview_value()
    |> preview_text()
    |> String.replace(~r/\s+/, " ")
    |> String.slice(0, 120)
  end

  defp preview_value(message) do
    Map.get(message, :text) || Map.get(message, :result) || Map.get(message, :error) || ""
  end

  defp preview_text(text) when is_binary(text), do: text
  defp preview_text(value), do: inspect(value, limit: 20)
end
