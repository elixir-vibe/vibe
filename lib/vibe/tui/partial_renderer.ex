defmodule Vibe.TUI.PartialRenderer do
  @moduledoc "Renderer-level partial rendering for semantic TUI view models."

  alias Vibe.Support.Lists
  alias Vibe.TUI.{Renderable, RenderContext, RenderState, Theme, Widget}

  @type result :: %{body: [IO.chardata()], state: RenderState.t(), live_keys: [term()]}

  @spec render_body(map(), pos_integer(), Theme.t(), RenderState.t(), keyword()) :: result()
  def render_body(view, width, theme, %RenderState{} = state, opts \\ []) do
    context = RenderContext.new(width, theme, state, opts)

    plugin_widgets =
      Lists.join(plugin_widgets(view, :above_editor), plugin_widgets(view, :sidebar))

    {sections, context, live_keys} =
      {[], context, []}
      |> append_many(interspersed_body(view))
      |> append_many(plugin_widgets)
      |> append_if(notice_margin?(view, plugin_widgets), spacer_component(:notice_margin))
      |> append_one(Map.get(view, :notifications))
      |> append_one(picker_component(Map.get(view, :picker)))
      |> append_if(footer_margin?(view, plugin_widgets), spacer_component(:footer_margin))
      |> append_one(Map.fetch!(view, :footer))
      |> append_many(plugin_widgets(view, :below_editor))
      |> append_many(overlay_components(Map.fetch!(view, :overlays)))

    live_keys = Enum.reverse(live_keys)

    %{
      body: sections |> Enum.reverse() |> Enum.flat_map(& &1),
      state: RenderState.prune(context.state, live_keys),
      live_keys: live_keys
    }
  end

  defp append_many(acc, components), do: Enum.reduce(components, acc, &append_one(&2, &1))

  defp append_one(acc, nil), do: acc

  defp append_one({sections, context, live_keys}, component) do
    {lines, context, key} = render_cached(component, context)
    {[lines | sections], context, [key | live_keys]}
  end

  defp append_if(acc, true, component), do: append_one(acc, component)
  defp append_if(acc, false, _component), do: acc

  defp render_cached(component, context) do
    key = render_key(component, context)

    case RenderState.fetch(context.state, key) do
      {:ok, lines, state} ->
        {lines, %{context | state: state}, key}

      :miss ->
        lines = render_component(component, context)
        {lines, %{context | state: RenderState.put(context.state, key, lines)}, key}
    end
  end

  defp render_key({:node, id, node}, context),
    do: {:node, id, node.type, node.props, context.width, context.theme.name}

  defp render_key(component, context), do: Renderable.render_key(component, context)

  defp render_component({:node, _id, node}, context),
    do: Widget.render(node, context.width, context.theme)

  defp render_component(component, context), do: Renderable.render(component, context)

  defp interspersed_body(view) do
    view
    |> Map.fetch!(:body)
    |> Enum.intersperse(spacer_component(:body))
  end

  defp plugin_widgets(view, placement) do
    view
    |> Map.fetch!(:plugin_widgets)
    |> Map.get(placement, [])
  end

  defp picker_component(%{type: type, props: props}),
    do: {:node, {:picker, type, props}, Vibe.TUI.node(type, props)}

  defp picker_component(_picker), do: nil

  defp overlay_components(overlays) do
    overlays
    |> Enum.reject(&(&1.kind == :confirmation))
    |> Enum.map(&{:node, {:overlay, &1}, Vibe.TUI.overlay(&1)})
  end

  defp spacer_component(id), do: {:node, {:spacer, id}, Vibe.TUI.spacer()}

  defp notice_margin?(view, plugin_widgets) do
    not is_nil(Map.get(view, :notifications)) and
      (Map.fetch!(view, :body) != [] or plugin_widgets != [])
  end

  defp footer_margin?(view, plugin_widgets) do
    Map.fetch!(view, :body) != [] or plugin_widgets != [] or
      not is_nil(Map.get(view, :notifications)) or
      not is_nil(Map.get(view, :picker))
  end
end
