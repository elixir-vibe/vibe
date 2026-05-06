defmodule Vibe.TUI.PickerPresenter do
  @moduledoc "Converts semantic picker state into TUI picker nodes."

  @spec from_snapshot(map()) :: %{type: atom(), props: map()} | nil
  def from_snapshot(%{ui: %{selector: %{overlay_kind: :confirmation} = selector}}) do
    %{type: :confirmation, props: Map.from_struct(selector)}
  end

  def from_snapshot(%{ui: %{selector: selector}}) when is_map(selector) do
    %{type: :select_list, props: selector}
  end

  def from_snapshot(%{autocomplete: nil}), do: nil

  def from_snapshot(%{autocomplete: autocomplete}) do
    %{type: :autocomplete, props: Map.from_struct(autocomplete)}
  end
end
