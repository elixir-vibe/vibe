defmodule Vibe.TUI.Widgets.Tools.Generic do
  @moduledoc "TUI tool widget: fallback for unrecognized tools."
  @behaviour Vibe.TUI.ToolWidget

  @impl true
  def render(tool, width, theme), do: Vibe.TUI.ToolWidget.generic_lines(tool, width, theme)
end
