defmodule Vibe.TUI.Renderer do
  @moduledoc """
  Terminal renderer for Vibe's semantic UI view model.

  This renderer delegates layout to the declarative chat view and returns iodata
  lines. Semantic state lives in `Vibe.UI`.
  """

  alias Vibe.TUI.{FrameRenderer, RenderFrame, RenderState, Views.Chat}
  alias Vibe.Terminal.{Theme}
  alias Vibe.UI.ViewModel

  @type line :: IO.chardata()

  @spec render(ViewModel.t(), pos_integer(), Theme.t()) :: [line()]
  def render(view, width, theme \\ Theme.default())
      when is_map(view) and is_integer(width) and width > 0 do
    Chat.render_lines(view, width, theme)
  end

  @spec render_frame(map(), Theme.t(), RenderState.t(), keyword()) :: RenderFrame.t()
  def render_frame(snapshot, theme, %RenderState{} = state, opts \\ []) when is_map(snapshot) do
    FrameRenderer.render(snapshot, theme, state, opts)
  end

  @spec render_frame_with_body(map(), Theme.t(), RenderState.t(), [IO.chardata()], keyword()) ::
          RenderFrame.t()
  def render_frame_with_body(snapshot, theme, %RenderState{} = state, body, opts \\ [])
      when is_map(snapshot) and is_list(body) do
    FrameRenderer.render_with_body(snapshot, theme, state, body, opts)
  end
end
