defmodule Vibe.Transport.JSON.Value do
  @moduledoc false

  @spec value(term()) :: term()
  def value(value) when is_boolean(value) or is_nil(value), do: value
  def value(value) when is_atom(value), do: Atom.to_string(value)
  def value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def value(%Date{} = value), do: Date.to_iso8601(value)

  def value(%_{} = value) do
    raise ArgumentError,
          "no transport JSON projection for #{inspect(value.__struct__)}; add a Vibe.Transport.JSON.Encodable implementation"
  end

  def value(value) when is_binary(value) do
    if String.valid?(value), do: value, else: %{type: "binary", data: Base.encode64(value)}
  end

  def value(value) when is_number(value), do: value
  def value(value) when is_tuple(value), do: value |> Tuple.to_list() |> value()
  def value(value) when is_list(value), do: Enum.map(value, &value/1)

  def value(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {key(key), value(value)} end)
  end

  def value(value) do
    raise ArgumentError,
          "no transport JSON projection for #{inspect(value)}; add a Vibe.Transport.JSON.Encodable implementation"
  end

  @spec key(term()) :: String.t()
  def key(term) when is_atom(term), do: Atom.to_string(term)
  def key(term) when is_binary(term), do: term
  def key(term), do: to_string(term)
end
