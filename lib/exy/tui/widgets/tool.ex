defmodule Exy.TUI.Widgets.Tool do
  @moduledoc "TUI widget: tool call card with summary and output."
  @behaviour Exy.TUI.Widget

  @impl true
  def render(%{props: props}, width, theme), do: Exy.TUI.ToolWidget.render(props, width, theme)
end
