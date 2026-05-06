defmodule Vibe.TUI.ChatTree do
  @moduledoc "Builds the shared semantic render tree for chat TUI renderers."

  alias Vibe.Support.Lists
  alias Vibe.TUI.{Node, RenderTree}
  alias Vibe.UI.Block
  alias Vibe.UI.Block.ToolCall

  @spec build(map()) :: RenderTree.t()
  def build(view) when is_map(view) do
    plugin_widgets =
      Lists.join(plugin_widgets(view, :above_editor), plugin_widgets(view, :sidebar))

    nodes =
      []
      |> append_many(interspersed_body(view))
      |> append_many(plugin_widgets)
      |> append_if(notice_margin?(view, plugin_widgets), spacer_component(:notice_margin))
      |> append_one(Map.get(view, :notifications))
      |> append_one(picker_component(Map.get(view, :picker)))
      |> append_if(footer_margin?(view, plugin_widgets), spacer_component(:footer_margin))
      |> append_one(Map.fetch!(view, :footer))
      |> append_many(plugin_widgets(view, :below_editor))
      |> append_many(overlay_components(Map.fetch!(view, :overlays)))
      |> Enum.reverse()

    RenderTree.new(nodes)
  end

  @spec to_tui_node(RenderTree.t()) :: Node.t()
  def to_tui_node(%RenderTree{nodes: nodes}) do
    nodes
    |> Enum.map(&component_node/1)
    |> Vibe.TUI.vertical()
  end

  defp append_many(nodes, components), do: Enum.reduce(components, nodes, &append_one(&2, &1))
  defp append_one(nodes, nil), do: nodes
  defp append_one(nodes, %RenderTree.Node{} = node), do: [node | nodes]
  defp append_one(nodes, component), do: [semantic_component(component) | nodes]
  defp append_if(nodes, true, component), do: append_one(nodes, component)
  defp append_if(nodes, false, _component), do: nodes

  defp interspersed_body(view) do
    view
    |> Map.fetch!(:body)
    |> Enum.map(&semantic_component/1)
    |> Enum.intersperse(spacer_component(:body))
  end

  defp semantic_component(%ToolCall{} = tool), do: RenderTree.node({:tool_call, tool.id}, tool)

  defp semantic_component(%Block.PluginWidget{} = widget),
    do: RenderTree.node({:plugin_widget, widget.id}, widget)

  defp semantic_component(%Block.NotificationList{} = notifications),
    do: RenderTree.node(:notifications, notifications)

  defp semantic_component(%Block.Footer{} = footer), do: RenderTree.node(:footer, footer)
  defp semantic_component(%{id: id} = block), do: RenderTree.node({:message, id}, block)
  defp semantic_component(block), do: RenderTree.node({:message, :erlang.phash2(block)}, block)

  defp plugin_widgets(view, placement) do
    view
    |> Map.fetch!(:plugin_widgets)
    |> Map.get(placement, [])
    |> Enum.map(&RenderTree.node({:plugin_widget, &1.id}, &1))
  end

  defp picker_component(%{type: type, props: props}) do
    node = Vibe.TUI.node(type, props)
    RenderTree.node({:picker, type, :erlang.phash2(props)}, node)
  end

  defp picker_component(%Node{} = node),
    do: RenderTree.node({:picker, node.type, :erlang.phash2(node.props)}, node)

  defp picker_component(_picker), do: nil

  defp overlay_components(overlays) do
    overlays
    |> Enum.reject(&(&1.kind == :confirmation))
    |> Enum.map(&RenderTree.node({:overlay, &1.kind, :erlang.phash2(&1)}, Vibe.TUI.overlay(&1)))
  end

  defp spacer_component(id), do: RenderTree.node({:spacer, id}, Vibe.TUI.spacer())

  defp notice_margin?(view, plugin_widgets) do
    not is_nil(Map.get(view, :notifications)) and
      (Map.fetch!(view, :body) != [] or plugin_widgets != [])
  end

  defp footer_margin?(view, plugin_widgets) do
    Map.fetch!(view, :body) != [] or plugin_widgets != [] or
      not is_nil(Map.get(view, :notifications))
  end

  defp component_node(%RenderTree.Node{component: %ToolCall{} = tool}), do: Vibe.TUI.tool(tool)

  defp component_node(%RenderTree.Node{component: %Block.PluginWidget{} = widget}),
    do: Vibe.TUI.plugin_widget(widget)

  defp component_node(%RenderTree.Node{component: %Block.NotificationList{} = notifications}),
    do: Vibe.TUI.notifications(notifications)

  defp component_node(%RenderTree.Node{component: %Block.Footer{} = footer}),
    do: Vibe.TUI.footer(footer)

  defp component_node(%RenderTree.Node{component: %Node{} = node}), do: node
  defp component_node(%RenderTree.Node{component: message}), do: Vibe.TUI.message(message)
end
