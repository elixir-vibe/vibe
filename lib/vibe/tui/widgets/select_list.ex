defmodule Vibe.TUI.Widgets.SelectList do
  @moduledoc "TUI widget: navigable selection list."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.Widgets.ListPanel

  @impl true
  def render(%{props: props}, width, theme) do
    items = Map.get(props, :items, [])
    selected = Map.get(props, :selected, 0)
    limit = Map.get(props, :limit, 8)

    ListPanel.render(
      %{
        title: Map.get(props, :title),
        query: Map.get(props, :query, ""),
        items: items,
        selected: selected,
        limit: limit,
        offset: Vibe.TUI.Viewport.offset(length(items), selected, limit),
        empty_message: Map.get(props, :empty_message)
      },
      width,
      theme
    )
  end
end
