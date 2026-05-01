defmodule Exy.UI.Selector do
  @moduledoc "Internal implementation module."
  @type t :: %__MODULE__{
          kind: atom() | nil,
          overlay_kind: atom() | nil,
          title: String.t() | nil,
          message: String.t() | nil,
          items: [term()],
          selected: non_neg_integer(),
          limit: pos_integer() | nil
        }

  defstruct [:kind, :overlay_kind, :title, :message, :limit, items: [], selected: 0]

  @spec new(t() | map() | keyword()) :: t()
  def new(%__MODULE__{} = selector), do: selector
  def new(fields) when is_list(fields), do: fields |> Map.new() |> new()

  def new(%{kind: kind} = fields) do
    %__MODULE__{
      kind: kind,
      overlay_kind: Map.get(fields, :overlay_kind),
      title: Map.get(fields, :title),
      message: Map.get(fields, :message),
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
  def overlay(%__MODULE__{} = selector) do
    selector
    |> Map.from_struct()
    |> Map.put(:selector_kind, selector.kind)
    |> Map.put(:kind, selector.overlay_kind || :selector)
  end

  defp clamp(_selected, 0), do: 0
  defp clamp(selected, count), do: selected |> max(0) |> min(count - 1)
end
