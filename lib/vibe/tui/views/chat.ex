defmodule Vibe.TUI.Views.Chat do
  @moduledoc """
  Default declarative chat TUI view.
  """

  use Vibe.TUI

  alias Vibe.Support.Lists
  alias Vibe.TUI.Node
  alias Vibe.UI.Block.ToolCall

  defui do
    body =
      for block <- assign(:body) do
        case block do
          %ToolCall{} -> tool(block)
          _ -> message(block)
        end
      end

    body = Enum.intersperse(body, spacer())
    widget_slots = assign(:plugin_widgets)
    above_editor_widgets = Enum.map(Map.get(widget_slots, :above_editor, []), &plugin_widget/1)
    below_editor_widgets = Enum.map(Map.get(widget_slots, :below_editor, []), &plugin_widget/1)
    sidebar_widgets = Enum.map(Map.get(widget_slots, :sidebar, []), &plugin_widget/1)
    plugin_widgets = Lists.join(above_editor_widgets, sidebar_widgets)
    notices = if assign(:notifications), do: [notifications(assign(:notifications))], else: []

    picker =
      case Map.get(assigns, :picker) do
        %{type: type, props: props} -> [Vibe.TUI.node(type, props)]
        %Node{} = node -> [node]
        _picker -> []
      end

    overlays =
      assign(:overlays)
      |> Enum.reject(&(&1.kind == :confirmation))
      |> Enum.map(&overlay/1)

    notice_margin =
      if notices != [] and (body != [] or plugin_widgets != []), do: [spacer()], else: []

    footer_margin =
      if body == [] and plugin_widgets == [] and notices == [] and picker == [],
        do: [],
        else: [spacer()]

    vertical(
      List.flatten([
        body,
        plugin_widgets,
        notice_margin,
        notices,
        picker,
        footer_margin,
        footer(assign(:footer)),
        below_editor_widgets,
        overlays
      ])
    )
  end
end
