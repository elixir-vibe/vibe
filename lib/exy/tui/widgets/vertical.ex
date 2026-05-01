defmodule Exy.TUI.Widgets.Vertical do
  @moduledoc "Internal implementation module."
  @behaviour Exy.TUI.Widget

  @impl true
  def render(%{children: children}, width, theme) do
    Enum.flat_map(children, &Exy.TUI.Widget.render(&1, width, theme))
  end
end
