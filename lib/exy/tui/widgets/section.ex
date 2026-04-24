defmodule Exy.TUI.Widgets.Section do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Width}

  @impl true
  def render(%{props: %{title: title}, children: children}, width, theme) do
    header = section_header(title, width, theme)
    [header | Enum.flat_map(children, &Exy.TUI.Widget.render(&1, width, theme))]
  end

  defp section_header(title, width, theme) do
    title = IO.iodata_to_binary(title)
    line_len = max(width - Width.visible_length(title) - 1, 0)

    [
      Theme.fg(theme, :accent, title),
      " ",
      Theme.fg(theme, :border, String.duplicate(Theme.symbol(theme, :section_line), line_len))
    ]
  end
end
