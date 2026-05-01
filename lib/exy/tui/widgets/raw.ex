defmodule Exy.TUI.Widgets.Raw do
  @moduledoc "Internal implementation module."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Widget

  @impl true
  def render(%{children: [content]}, width, _theme), do: Widget.wrap(content, width)
end
