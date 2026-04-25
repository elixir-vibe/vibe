defmodule Exy.TUI.Widgets.Loader do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Theme

  @default_label "Thinking"
  @glyphs ["✦", "⋰", "⋱", "✧"]

  @impl true
  def render(%{props: props}, _width, theme) do
    label = Map.get(props, :label, @default_label)
    [[art(theme), " ", Theme.italic(Theme.fg(theme, :thinking_text, [label, "…"]))]]
  end

  defp art(theme) do
    Theme.fg(theme, :accent, Enum.intersperse(@glyphs, " "))
  end
end
