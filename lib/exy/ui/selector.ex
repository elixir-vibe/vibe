defmodule Exy.UI.Selector do
  @moduledoc false

  @type t :: %__MODULE__{
          kind: atom() | nil,
          title: String.t() | nil,
          items: [term()],
          selected: non_neg_integer(),
          limit: pos_integer() | nil
        }

  defstruct [:kind, :title, :limit, items: [], selected: 0]

  @spec new(t() | map() | keyword()) :: t()
  def new(%__MODULE__{} = selector), do: selector
  def new(fields) when is_list(fields), do: fields |> Map.new() |> new()

  def new(%{kind: kind} = fields) do
    %__MODULE__{
      kind: kind,
      title: Map.get(fields, :title),
      items: Map.get(fields, :items, []),
      selected: Map.get(fields, :selected, 0),
      limit: Map.get(fields, :limit)
    }
  end

  @spec move(t(), integer()) :: t()
  def move(%__MODULE__{} = selector, direction) do
    count = length(selector.items)
    %{selector | selected: clamp(selector.selected + direction, count)}
  end

  @spec overlay(t()) :: map()
  def overlay(%__MODULE__{} = selector),
    do: selector |> Map.from_struct() |> Map.put(:kind, :selector)

  defp clamp(_selected, 0), do: 0
  defp clamp(selected, count), do: selected |> max(0) |> min(count - 1)
end
