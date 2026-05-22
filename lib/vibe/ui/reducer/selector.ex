defmodule Vibe.UI.Reducer.Selector do
  @moduledoc "Selector-specific reducer operations."

  alias Vibe.Support.Lists
  alias Vibe.UI.Selector

  @spec open(map(), term()) :: map()
  def open(state, data) do
    selector = Selector.new(data)

    %{
      state
      | selector: selector,
        overlays: Lists.append(state.overlays, Selector.overlay(selector))
    }
  end

  @spec open_confirmation(map(), map()) :: map()
  def open_confirmation(state, data) do
    open(
      state,
      data
      |> Map.put_new(:kind, :confirmation)
      |> Map.put(:overlay_kind, :confirmation)
      |> Map.put_new(:items, [Map.get(data, :confirm, "Yes"), Map.get(data, :cancel, "No")])
      |> Map.put_new(:selected, 0)
      |> Map.put_new(:limit, 2)
    )
  end

  @spec move(map(), integer()) :: map()
  def move(state, direction) do
    %{
      state
      | selector: move_selector(state.selector, direction),
        overlays: update_selector_overlay(state.overlays, direction)
    }
  end

  @spec close(map()) :: map()
  def close(state) do
    %{state | selector: nil, overlays: Enum.reject(state.overlays, &selector_overlay?/1)}
  end

  defp selector_overlay?(%{kind: kind}) when kind in [:selector, :confirmation], do: true
  defp selector_overlay?(_overlay), do: false

  defp move_selector(nil, _direction), do: nil
  defp move_selector(%Selector{} = selector, direction), do: Selector.move(selector, direction)

  defp move_selector(selector, direction),
    do: selector |> Selector.new() |> Selector.move(direction)

  defp update_selector_overlay(overlays, direction) do
    Enum.map(overlays, fn
      %{kind: kind} = overlay when kind in [:selector, :confirmation] ->
        overlay
        |> Map.put(:kind, Map.get(overlay, :selector_kind, kind))
        |> Map.put(:overlay_kind, kind)
        |> Selector.new()
        |> Selector.move(direction)
        |> Selector.overlay()

      overlay ->
        overlay
    end)
  end
end
