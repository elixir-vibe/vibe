defmodule Exy.TUI.Widgets.Overlay do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{DSL, Theme, Widget}

  @impl true
  def render(%{props: %{kind: :selector} = props}, width, theme) do
    props
    |> DSL.select_list()
    |> Widget.render(width, theme)
  end

  def render(%{props: %{kind: kind}}, width, theme) do
    line = kind |> then(&["Overlay: ", to_string(&1)]) |> Widget.fit_line(width)
    [Theme.fg(theme, :accent, line)]
  end
end
