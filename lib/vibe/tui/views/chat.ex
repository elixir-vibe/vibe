defmodule Vibe.TUI.Views.Chat do
  @moduledoc "Default declarative chat TUI view."

  alias Vibe.TUI.{ChatTree, Theme, Widget}

  @spec render(map()) :: Vibe.TUI.Node.t()
  def render(assigns \\ %{}) when is_map(assigns) do
    assigns
    |> ChatTree.build()
    |> ChatTree.to_tui_node()
  end

  @spec render_lines(map(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render_lines(assigns \\ %{}, width, theme \\ Theme.default()) do
    assigns |> render() |> Widget.render(width, theme)
  end
end
