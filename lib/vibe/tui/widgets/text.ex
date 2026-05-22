defmodule Vibe.TUI.Widgets.Text do
  @moduledoc "TUI widget: styled text block."
  @behaviour Vibe.TUI.Widget

  alias Vibe.Terminal.{Theme}
  alias Vibe.TUI.Widget

  @impl true
  def render(%{props: props, children: [content]}, width, theme) do
    content
    |> style(props, theme)
    |> Widget.wrap(width)
  end

  defp style(content, props, theme) do
    content
    |> maybe_style(props, theme, :fg, &Theme.fg/3)
    |> maybe_style(props, theme, :bg, &Theme.bg/3)
  end

  defp maybe_style(content, props, theme, key, fun) do
    case Map.get(props, key) do
      nil -> content
      color -> fun.(theme, color, content)
    end
  end
end
