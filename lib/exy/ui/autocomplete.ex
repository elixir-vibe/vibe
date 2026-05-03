defmodule Exy.UI.Autocomplete do
  @moduledoc "Internal implementation module."
  defmodule Item do
    @moduledoc "Internal implementation module."
    @type t :: %__MODULE__{
            value: String.t(),
            label: String.t(),
            detail: String.t() | nil,
            group: atom() | nil
          }

    defstruct [:value, :label, :detail, :group]

    @spec new(t() | map() | keyword() | String.t()) :: t()
    def new(%__MODULE__{} = item), do: item
    def new(value) when is_binary(value), do: %__MODULE__{value: value, label: value}
    def new(fields) when is_list(fields), do: fields |> Map.new() |> new()

    def new(%{value: value} = fields) when is_binary(value) do
      %__MODULE__{
        value: value,
        label: Map.get(fields, :label, value),
        detail: Map.get(fields, :detail),
        group: Map.get(fields, :group)
      }
    end
  end

  @type t :: %__MODULE__{
          title: String.t() | nil,
          query: String.t(),
          items: [Item.t()],
          selected: non_neg_integer(),
          limit: pos_integer(),
          empty_message: String.t() | nil,
          replace_from: non_neg_integer() | nil
        }

  defstruct [:title, :empty_message, :replace_from, query: "", items: [], selected: 0, limit: 8]

  @spec new(t() | map() | keyword()) :: t()
  def new(%__MODULE__{} = autocomplete), do: autocomplete
  def new(fields) when is_list(fields), do: fields |> Map.new() |> new()

  def new(fields) when is_map(fields) do
    items = fields |> Map.get(:items, []) |> Enum.map(&Item.new/1)

    %__MODULE__{
      title: Map.get(fields, :title),
      query: Map.get(fields, :query, ""),
      items: items,
      selected: fields |> Map.get(:selected, 0) |> clamp(length(items)),
      limit: Map.get(fields, :limit, 8),
      empty_message: Map.get(fields, :empty_message),
      replace_from: Map.get(fields, :replace_from)
    }
  end

  @spec filter([Item.t() | map() | keyword() | String.t()], String.t(), keyword()) :: t() | nil
  def filter(items, query, opts \\ []) when is_binary(query) do
    query = String.trim_leading(query)

    filtered =
      items
      |> Enum.map(&Item.new/1)
      |> Enum.filter(&matches?(&1, query))

    if filtered == [] and query == "" do
      nil
    else
      new(
        title: Keyword.get(opts, :title),
        query: query,
        items: filtered,
        selected: 0,
        limit: Keyword.get(opts, :limit, 8),
        empty_message: Keyword.get(opts, :empty_message, "No matches")
      )
    end
  end

  @spec move(t(), integer()) :: t()
  def move(%__MODULE__{items: []} = autocomplete, _direction), do: autocomplete

  def move(%__MODULE__{} = autocomplete, direction) do
    count = length(autocomplete.items)

    %{
      autocomplete
      | selected: (autocomplete.selected + direction) |> Integer.mod(count)
    }
  end

  @spec selected_item(t() | nil) :: Item.t() | nil
  def selected_item(nil), do: nil

  def selected_item(%__MODULE__{} = autocomplete),
    do: Enum.at(autocomplete.items, autocomplete.selected)

  defp matches?(_item, ""), do: true

  defp matches?(%Item{} = item, query) do
    query = String.downcase(query)

    Enum.any?([item.value, item.label, item.detail], fn
      nil -> false
      text -> text |> String.downcase() |> String.contains?(query)
    end)
  end

  defp clamp(_selected, 0), do: 0
  defp clamp(selected, count), do: selected |> max(0) |> min(count - 1)
end
