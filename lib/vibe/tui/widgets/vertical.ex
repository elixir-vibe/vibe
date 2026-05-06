defmodule Vibe.TUI.Widgets.Vertical do
  @moduledoc "TUI widget: vertical layout container."
  @behaviour Vibe.TUI.Widget

  @impl true
  def render(%{children: children}, width, theme) do
    Enum.flat_map(children, &Vibe.TUI.Widget.render(&1, width, theme))
  end
end
