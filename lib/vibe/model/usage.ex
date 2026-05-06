defmodule Vibe.Model.Usage do
  @moduledoc """
  Normalized model usage extraction for session accounting.
  """

  @type t :: %{
          optional(:model) => String.t(),
          optional(:input_tokens) => non_neg_integer(),
          optional(:output_tokens) => non_neg_integer(),
          optional(:total_tokens) => non_neg_integer(),
          optional(:total_cost) => number(),
          optional(:cost) => map()
        }

  @spec from_response(term()) :: t() | nil
  def from_response(%{usage: usage} = response) when is_map(usage) do
    usage
    |> usage_fields()
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
        usage = usage_fields(usage)

        acc
        |> add(:input_tokens, usage)
        |> add(:output_tokens, usage)
        |> add_total_tokens(usage)
        |> add_float(:total_cost, usage)
      end
    )
  end

  defp usage_fields(%_{} = struct), do: struct |> Map.from_struct() |> usage_fields()

  defp usage_fields(map) when is_map(map) do
    %{}
    |> put_known(:input_tokens, value(map, :input_tokens))
    |> put_known(:output_tokens, value(map, :output_tokens))
    |> put_known(:total_tokens, value(map, :total_tokens))
    |> put_known(:total_cost, value(map, :total_cost))
    |> put_known(:cost, value(map, :cost))
  end

  defp value(map, key), do: Map.get(map, key, Map.get(map, to_string(key)))

  defp put_known(map, _key, nil), do: map
  defp put_known(map, key, value), do: Map.put(map, key, value)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp add(acc, key, usage), do: Map.update!(acc, key, &(&1 + integer_value(usage[key])))

  defp add_total_tokens(acc, usage) do
    total = integer_value(usage[:total_tokens])

    if total > 0 do
      Map.update!(acc, :total_tokens, &(&1 + total))
    else
      Map.update!(
        acc,
        :total_tokens,
        &(&1 + integer_value(usage[:input_tokens]) + integer_value(usage[:output_tokens]))
      )
    end
  end

  defp add_float(acc, key, usage), do: Map.update!(acc, key, &(&1 + float_value(usage[key])))

  defp integer_value(value) when is_integer(value), do: value
  defp integer_value(_value), do: 0

  defp float_value(value) when is_integer(value), do: value * 1.0
  defp float_value(value) when is_float(value), do: value
  defp float_value(_value), do: 0.0
end
