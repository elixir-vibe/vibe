defmodule Exy.TUI.Views.Chat do
  @moduledoc """
  Default declarative chat TUI view.
  """

  use Exy.TUI

  defui do
    body =
      for block <- assign(:body) do
        case block do
          %Exy.UI.Block.ToolCall{} -> tool(block)
          _ -> message(block)
        end
      end

    body = Enum.intersperse(body, spacer())
    widget_slots = assign(:plugin_widgets)
    above_editor_widgets = Enum.map(Map.get(widget_slots, :above_editor, []), &plugin_widget/1)
    below_editor_widgets = Enum.map(Map.get(widget_slots, :below_editor, []), &plugin_widget/1)
    sidebar_widgets = Enum.map(Map.get(widget_slots, :sidebar, []), &plugin_widget/1)
    plugin_widgets = Exy.Support.Lists.join(above_editor_widgets, sidebar_widgets)
    notices = if assign(:notifications), do: [notifications(assign(:notifications))], else: []
    overlays = Enum.map(assign(:overlays), &overlay/1)

    footer_margin =
      if body == [] and plugin_widgets == [] and notices == [], do: [], else: [spacer()]

    vertical(
      List.flatten([
        body,
        plugin_widgets,
        notices,
        footer_margin,
        footer(assign(:footer)),
        below_editor_widgets,
        overlays
      ])
    )
  end
end
