defmodule Vibe.TUI.PickerPresenter do
  @moduledoc "Converts semantic picker state into TUI picker nodes."

  @spec from_snapshot(map()) :: %{type: atom(), props: map()} | nil
  def from_snapshot(%{ui: %{selector: %{overlay_kind: :confirmation} = selector}}) do
    %{type: :confirmation, props: selector_props(selector)}
  end

  def from_snapshot(%{ui: %{selector: selector}}) when is_map(selector) do
    %{type: :select_list, props: selector}
  end

  def from_snapshot(%{autocomplete: nil}), do: nil

  def from_snapshot(%{autocomplete: autocomplete}) do
    %{type: :autocomplete, props: Map.from_struct(autocomplete)}
  end

  defp selector_props(%_{} = selector), do: Map.from_struct(selector)
  defp selector_props(selector) when is_map(selector), do: selector
end
