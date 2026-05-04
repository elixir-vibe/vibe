defmodule Exy.TUI.Widgets.Spacer do
  @moduledoc "TUI widget: vertical space."
  @behaviour Exy.TUI.Widget

  @impl true
  def render(%{props: props}, _width, _theme) do
    count = props |> Map.get(:lines, 1) |> max(0)
    List.duplicate("", count)
  end
end
