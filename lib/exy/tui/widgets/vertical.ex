defmodule Exy.TUI.Widgets.Vertical do
  @moduledoc "TUI widget: vertical layout container."
  @behaviour Exy.TUI.Widget

  @impl true
  def render(%{children: children}, width, theme) do
    Enum.flat_map(children, &Exy.TUI.Widget.render(&1, width, theme))
  end
end
