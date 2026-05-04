defmodule Exy.TUI.Widgets.Dialog do
  @moduledoc "TUI widget: modal dialog with message and actions."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Lines, Theme}
  alias Exy.TUI.Widgets.Frame

  @impl true
  def render(%{props: props, children: children}, width, theme) do
    title = Map.fetch!(props, :title)
    top = Frame.border(theme, width, :dialog_top_left, :dialog_top_right)
    heading = Frame.line(Theme.fg(theme, :accent, title), width, theme)
    bottom = Frame.border(theme, width, :dialog_bottom_left, :dialog_bottom_right)

    children
    |> Frame.body(width, theme)
    |> append_hint(Map.get(props, :hint), width, theme)
    |> Lines.append(bottom)
    |> then(&[top, heading | &1])
  end

  defp append_hint(lines, nil, _width, _theme), do: lines

  defp append_hint(lines, hint, width, theme) do
    Lines.append(lines, Frame.line(Theme.fg(theme, :muted, hint), width, theme))
  end
end
