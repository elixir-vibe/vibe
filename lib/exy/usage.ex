defmodule Exy.Usage do
  @moduledoc """
  Normalized model usage extraction for session accounting.
  """

  @type t :: %{
          optional(:model) => String.t(),
          optional(:input_tokens) => non_neg_integer(),
          optional(:output_tokens) => non_neg_integer(),
          optional(:total_tokens) => non_neg_integer(),
          optional(:cost) => map(),
          optional(atom()) => term()
        }

  @spec from_response(term()) :: t() | nil
  def from_response(%{usage: usage} = response) when is_map(usage) do
    usage
    |> normalize_keys()
    |> maybe_put(:model, Map.get(response, :model))
  end

  def from_response({:ok, response}), do: from_response(response)
  def from_response(_response), do: nil

  @spec summarize([map()]) :: map()
  def summarize(usages) when is_list(usages) do
    usages
    |> Enum.reduce(
      %{input_tokens: 0, output_tokens: 0, total_tokens: 0, total_cost: 0.0},
      fn usage, acc ->
        usage = normalize_keys(usage)

        acc
        |> add(:input_tokens, usage)
        |> add(:output_tokens, usage)
        |> add(:total_tokens, usage)
        |> add_float(:total_cost, usage)
      end
    )
  end

  defp normalize_keys(%_{} = struct), do: struct |> Map.from_struct() |> normalize_keys()

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {normalize_key(key), normalize_value(value)} end)
  end

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key), do: key

  defp normalize_value(value) when is_map(value), do: normalize_keys(value)
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp add(acc, key, usage), do: Map.update!(acc, key, &(&1 + integer_value(usage[key])))
  defp add_float(acc, key, usage), do: Map.update!(acc, key, &(&1 + float_value(usage[key])))

  defp integer_value(value) when is_integer(value), do: value
  defp integer_value(_value), do: 0

  defp float_value(value) when is_integer(value), do: value * 1.0
  defp float_value(value) when is_float(value), do: value
  defp float_value(_value), do: 0.0
end
