defmodule Vibe.TUI.Renderer do
  @moduledoc """
  Terminal renderer for Vibe's semantic UI view model.

  This renderer delegates layout to the declarative chat view and returns iodata
  lines. Semantic state lives in `Vibe.UI`.
  """

  alias Vibe.TUI.{Theme, Views.Chat}
  alias Vibe.UI.ViewModel

  @type line :: IO.chardata()

  @spec render(ViewModel.t(), pos_integer(), Theme.t()) :: [line()]
  def render(view, width, theme \\ Theme.default())
      when is_map(view) and is_integer(width) and width > 0 do
    Chat.render_lines(view, width, theme)
  end
end
