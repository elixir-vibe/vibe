defmodule Exy.TUI.Widgets.PluginWidget do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Widget

  @impl true
  def render(%{props: props}, width, _theme) do
    props
    |> Map.get(:content, [])
    |> List.wrap()
    |> Enum.map(&Widget.fit_line(&1, width))
  end
end
