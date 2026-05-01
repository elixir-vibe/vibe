defmodule Exy.TUI.Widgets.Tool do
  @moduledoc "Internal implementation module."
  @behaviour Exy.TUI.Widget

  @impl true
  def render(%{props: props}, width, theme), do: Exy.TUI.ToolWidget.render(props, width, theme)
end
