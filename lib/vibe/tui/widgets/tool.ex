defmodule Vibe.TUI.Widgets.Tool do
  @moduledoc "TUI widget: tool call card with summary and output."
  @behaviour Vibe.TUI.Widget

  @impl true
  def render(%{props: props}, width, theme),
    do: Vibe.TUI.Presentation.Tool.render(props, width, theme)
end
