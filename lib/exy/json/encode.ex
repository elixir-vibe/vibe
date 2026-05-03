defmodule Exy.JSON.Encode do
  @moduledoc "JSON value normalization for Exy domain encoders."

  @spec value(term()) :: term()
  def value(term) when is_atom(term), do: Atom.to_string(term)

  def value(%DateTime{} = term), do: DateTime.to_iso8601(term)
  def value(%_{} = term), do: term |> Map.from_struct() |> value()

  def value(term) when is_binary(term) or is_number(term) or is_boolean(term) or is_nil(term),
    do: term

  def value(term) when is_tuple(term), do: term |> Tuple.to_list() |> value()
  def value(term) when is_list(term), do: Enum.map(term, &value/1)

  def value(term) when is_map(term) do
    Map.new(term, fn {key, value} -> {key(key), value(value)} end)
  rescue
    _exception -> inspect(term, limit: 50)
  end

  def value(term), do: inspect(term, limit: 50)

  @spec key(term()) :: String.t()
  def key(term) when is_atom(term), do: Atom.to_string(term)
  def key(term) when is_binary(term), do: term
  def key(term), do: to_string(term)
end
