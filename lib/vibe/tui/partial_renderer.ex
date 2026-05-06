defmodule Vibe.TUI.PartialRenderer do
  @moduledoc "Renderer-level partial rendering for semantic TUI view models."

  alias Vibe.TUI.{
    ChatTree,
    Lines,
    Renderable,
    RenderContext,
    RenderFrame,
    RenderKey,
    RenderState,
    RenderTree,
    Theme,
    Widget,
    Width
  }

  alias Vibe.UI.ViewModel

  @type result :: %{body: [IO.chardata()], state: RenderState.t(), live_keys: [term()]}

  @spec render_frame(map(), Theme.t(), RenderState.t(), keyword()) :: RenderFrame.t()
  def render_frame(snapshot, theme, %RenderState{} = state, opts \\ []) when is_map(snapshot) do
    view =
      snapshot.ui
      |> ViewModel.from_state()
      |> Map.put(:picker, Keyword.get(opts, :picker))

    editor = render_editor(snapshot, theme)
    %{body: body, state: render_state} = render_body(view, snapshot.width, theme, state, opts)

    lines = frame_lines(body, editor, snapshot.height, Keyword.get(opts, :viewport, :visible))

    cursor =
      editor_cursor_position(
        snapshot,
        editor_start_row(body, editor, snapshot.height, Keyword.get(opts, :viewport, :visible))
      )

    %RenderFrame{
      lines: lines,
      cursor: cursor,
      state: render_state,
      stats: RenderState.stats(render_state)
    }
  end

  @spec render_body(map(), pos_integer(), Theme.t(), RenderState.t(), keyword()) :: result()
  def render_body(view, width, theme, %RenderState{} = state, opts \\ []) do
    context = RenderContext.new(width, theme, state, opts)

    {sections, context, live_keys} =
      view
      |> ChatTree.build()
      |> Map.fetch!(:nodes)
      |> append_tree_nodes({[], context, []})

    live_keys = Enum.reverse(live_keys)

    %{
      body: sections |> Enum.reverse() |> Enum.flat_map(& &1),
      state: RenderState.prune(context.state, live_keys),
      live_keys: live_keys
    }
  end

  defp append_tree_nodes(nodes, acc), do: Enum.reduce(nodes, acc, &append_tree_node(&2, &1))

  defp append_tree_node({sections, context, live_keys}, %RenderTree.Node{} = node) do
    {lines, context, key} = render_cached(node, context)
    {[lines | sections], context, [key | live_keys]}
  end

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

  defp render_key(%RenderTree.Node{component: %Vibe.TUI.Node{} = component} = node, context),
    do:
      RenderKey.component(
        :node,
        node.id,
        RenderKey.fingerprint({component.type, component.props}),
        context
      )

  defp render_key(%RenderTree.Node{id: id, component: component}, context),
    do: RenderKey.component(:tree, id, Renderable.render_key(component, context), context)

  defp render_component(%RenderTree.Node{component: %Vibe.TUI.Node{} = node}, context),
    do: Widget.render(node, context.width, context.theme)

  defp render_component(%RenderTree.Node{component: component}, context),
    do: Renderable.render(component, context)

  defp render_editor(snapshot, theme) do
    Vibe.TUI.textarea(
      title: "Prompt",
      value: snapshot.editor.text,
      cursor: snapshot.editor.cursor,
      min_rows: min(max(snapshot.height - 8, 3), 8),
      placeholder: "Ask Vibe anything..."
    )
    |> Widget.render(snapshot.width, theme)
  end

  defp frame_lines(body, editor, height, :visible),
    do: body |> fit_body(height, editor) |> Lines.join(editor)

  defp frame_lines(body, editor, _height, :full), do: Lines.join(body, editor)

  defp editor_start_row(_body, editor, height, :visible), do: max(height - length(editor), 0)
  defp editor_start_row(body, _editor, _height, :full), do: length(body)

  defp fit_body(body, height, editor) when is_integer(height) do
    body_lines = max(height - length(editor), 1)
    Enum.take(body, -body_lines)
  end

  defp editor_cursor_position(snapshot, editor_start_row) do
    inner_width = max(snapshot.width - 4, 1)
    text = snapshot.editor.text || ""
    cursor = snapshot.editor.cursor || 0
    before_cursor = String.slice(text, 0, cursor)
    logical_lines = String.split(before_cursor, "\n")
    {previous_lines, current_line} = split_current_line(logical_lines)

    previous_rows =
      previous_lines
      |> Enum.map(&(&1 |> Widget.wrap(inner_width) |> length()))
      |> Enum.sum()

    current_width = Width.visible_length(current_line)

    row = editor_start_row + 2 + previous_rows + div(current_width, inner_width)
    column = 3 + rem(current_width, inner_width)

    {max(row, 1), max(column, 1)}
  end

  defp split_current_line([]), do: {[], ""}
  defp split_current_line([line]), do: {[], line}

  defp split_current_line([line | lines]) do
    {previous, current} = split_current_line(lines)
    {[line | previous], current}
  end
end
