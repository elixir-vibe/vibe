defmodule Vibe.TUI.Widgets.Box do
  @moduledoc "TUI widget: bordered box container."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.Lines
  alias Vibe.TUI.Widgets.Frame

  @impl true
  def render(%{props: props, children: children}, width, theme) do
    title = Map.get(props, :title)
    top = Frame.border(theme, width, :dialog_top_left, :dialog_top_right, title)
    bottom = Frame.border(theme, width, :dialog_bottom_left, :dialog_bottom_right)

    children
    |> Frame.body(width, theme)
    |> Lines.append(bottom)
    |> then(&[top | &1])
  end
end
