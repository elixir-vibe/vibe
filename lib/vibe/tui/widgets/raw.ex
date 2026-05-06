defmodule Vibe.TUI.Widgets.Raw do
  @moduledoc "TUI widget: pre-rendered iodata passthrough."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.Widget

  @impl true
  def render(%{children: [content]}, width, _theme), do: Widget.wrap(content, width)
end
