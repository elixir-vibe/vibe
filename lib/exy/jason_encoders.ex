defmodule Exy.JSONSafe do
  @moduledoc "Small JSON boundary helper for Exy domain encoders."

  @spec encode(term()) :: term()
  def encode(value) when is_atom(value), do: Atom.to_string(value)

  def encode(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def encode(%_{} = value), do: value |> Map.from_struct() |> encode()

  def encode(value)
      when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
      do: value

  def encode(value) when is_tuple(value), do: value |> Tuple.to_list() |> encode()
  def encode(value) when is_list(value), do: Enum.map(value, &encode/1)

  def encode(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {encode_key(key), encode(value)} end)
  rescue
    _exception -> inspect(value, limit: 50)
  end

  def encode(value), do: inspect(value, limit: 50)

  defp encode_key(key) when is_atom(key), do: Atom.to_string(key)
  defp encode_key(key) when is_binary(key), do: key
  defp encode_key(key), do: to_string(key)
end

defimpl Jason.Encoder, for: Tuple do
  @moduledoc "Encodes tuples as JSON arrays for tool outputs and telemetry payloads."

  def encode(tuple, opts) do
    tuple
    |> Tuple.to_list()
    |> Exy.JSONSafe.encode()
    |> Jason.Encode.list(opts)
  end
end
