defmodule Exy.TUI.Widgets.Box do
  @moduledoc "Internal implementation module."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Lines
  alias Exy.TUI.Widgets.Frame

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
