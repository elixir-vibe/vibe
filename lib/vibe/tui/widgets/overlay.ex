defmodule Vibe.TUI.Widgets.Overlay do
  @moduledoc "TUI widget: floating overlay panel."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI
  alias Vibe.Terminal.{Theme}
  alias Vibe.TUI.Widget

  @impl true
  def render(%{props: %{kind: :selector} = props}, width, theme) do
    props
    |> TUI.select_list()
    |> Widget.render(width, theme)
  end

  def render(%{props: %{kind: :confirmation} = props}, width, theme) do
    props
    |> TUI.confirmation()
    |> Widget.render(width, theme)
  end

  def render(%{props: %{kind: kind}}, width, theme) do
    line = kind |> then(&["Overlay: ", to_string(&1)]) |> Widget.fit_line(width)
    [Theme.fg(theme, :accent, line)]
  end
end
