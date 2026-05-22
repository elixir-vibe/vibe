defmodule Vibe.TUI.Widgets.Loader do
  @moduledoc "TUI widget: animated working/thinking indicator."
  @behaviour Vibe.TUI.Widget

  alias Vibe.Terminal.Theme

  @default_label "Thinking"
  @frames ["✦", "⋰", "⋱", "✧"]

  @impl true
  def render(%{props: props}, _width, theme) do
    label = Map.get(props, :label, @default_label)
    phase = Map.get(props, :phase, 0)
    [["  ", art(theme, phase), " ", Theme.italic(Theme.fg(theme, :thinking_text, [label, "…"]))]]
  end

  defp art(theme, phase) do
    frame = Enum.at(@frames, rem(phase, length(@frames)))
    Theme.fg(theme, :accent, frame)
  end
end
