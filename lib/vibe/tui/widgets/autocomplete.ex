defmodule Vibe.TUI.Widgets.Autocomplete do
  @moduledoc "TUI widget: autocomplete dropdown overlay."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.Widgets.ListPanel
  alias Vibe.UI.Autocomplete

  @impl true
  def render(%{props: props}, width, theme) do
    autocomplete = Autocomplete.new(props)

    ListPanel.render(
      %{
        title: autocomplete.title,
        query: autocomplete.query,
        items: autocomplete.items,
        selected: autocomplete.selected,
        limit: autocomplete.limit,
        empty_message: autocomplete.empty_message
      },
      width,
      theme
    )
  end
end
