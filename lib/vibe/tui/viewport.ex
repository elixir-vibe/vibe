defmodule Vibe.TUI.Viewport do
  @moduledoc "Shared viewport math for TUI widgets."

  @spec offset(non_neg_integer(), non_neg_integer(), pos_integer()) :: non_neg_integer()
  def offset(count, selected, limit) do
    cond do
      count <= limit -> 0
      selected < limit -> 0
      true -> min(selected - limit + 1, count - limit)
    end
  end
end
