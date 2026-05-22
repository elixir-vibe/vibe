defmodule Vibe.TUI.FrameRenderer do
  @moduledoc "Composes full TUI render frames from semantic snapshots."

  alias Vibe.TUI.{Cursor, EditorRenderer, PartialRenderer, RenderFrame, RenderState}
  alias Vibe.Terminal.{Lines, Theme}
  alias Vibe.UI.ViewModel

  @spec render(map(), Theme.t(), RenderState.t(), keyword()) :: RenderFrame.t()
  def render(snapshot, theme, %RenderState{} = state, opts \\ []) when is_map(snapshot) do
    view =
      snapshot.ui
      |> ViewModel.from_state()
      |> Map.put(:picker, Keyword.get(opts, :picker))

    editor = EditorRenderer.render(snapshot, theme)

    %{body: body, state: render_state} =
      PartialRenderer.render_body(view, snapshot.width, theme, state, opts)

    viewport = Keyword.get(opts, :viewport, :visible)

    %RenderFrame{
      lines: frame_lines(body, editor, snapshot.height, viewport),
      cursor:
        Cursor.editor_position(
          snapshot,
          editor_start_row(body, editor, snapshot.height, viewport)
        ),
      state: render_state,
      stats: RenderState.stats(render_state)
    }
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
end
