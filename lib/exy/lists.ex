defmodule Exy.Lists do
  @moduledoc false

  @spec append([term()], term()) :: [term()]
  def append(list, item), do: prepend_reversed(Enum.reverse(list), [item])

  @spec join([term()], [term()]) :: [term()]
  def join(left, right), do: prepend_reversed(Enum.reverse(left), right)

  @spec prepend_reversed([term()], [term()]) :: [term()]
  def prepend_reversed(items, tail), do: Enum.reduce(items, tail, &[&1 | &2])
end
