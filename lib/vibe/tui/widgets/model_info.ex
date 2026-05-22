defmodule Vibe.TUI.Widgets.ModelInfo do
  @moduledoc "TUI widget: model and effort status display."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.Widget
  alias Vibe.TUI.Widgets.ModelInfo.Parts

  @impl true
  def render(%{props: props}, width, theme) do
    [Widget.join_sides(Parts.model(props, theme), Parts.status(props, theme), width)]
  end
end
