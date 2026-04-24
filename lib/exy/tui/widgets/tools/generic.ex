defmodule Exy.TUI.Widgets.Tools.Generic do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  @impl true
  def render(tool, width, theme), do: Exy.TUI.ToolWidget.generic_lines(tool, width, theme)
end
