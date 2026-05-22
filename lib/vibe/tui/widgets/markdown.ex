defmodule Vibe.TUI.Widgets.Markdown do
  @moduledoc "TUI widget: rendered Markdown content block."
  @behaviour Vibe.TUI.Widget

  alias Vibe.Terminal.Markdown

  @impl true
  def render(%{children: [content | _]}, width, theme) do
    content
    |> IO.iodata_to_binary()
    |> Markdown.render(width, theme)
  end

  def render(_node, _width, _theme), do: []
end
