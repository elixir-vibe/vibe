defmodule Exy.TUI.Widgets.Markdown do
  @moduledoc "TUI widget: rendered Markdown content block."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Markdown

  @impl true
  def render(%{children: [content | _]}, width, theme) do
    content
    |> IO.iodata_to_binary()
    |> Markdown.render(width, theme)
  end

  def render(_node, _width, _theme), do: []
end
