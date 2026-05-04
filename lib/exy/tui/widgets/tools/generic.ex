defmodule Exy.TUI.Widgets.Tools.Generic do
  @moduledoc "TUI tool widget: fallback for unrecognized tools."
  @behaviour Exy.TUI.ToolWidget

  @impl true
  def render(tool, width, theme), do: Exy.TUI.ToolWidget.generic_lines(tool, width, theme)
end
