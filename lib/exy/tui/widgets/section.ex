defmodule Exy.TUI.Widgets.Section do
  @moduledoc "Internal implementation module."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget, Width}

  @impl true
  def render(%{props: %{title: title}, children: children}, width, theme) do
    header = section_header(title, width, theme)
    [header | Enum.flat_map(children, &Exy.TUI.Widget.render(&1, width, theme))]
  end

  defp section_header(title, width, theme) do
    title = IO.iodata_to_binary(title)
    line_len = width - Width.visible_length(title) - 1

    [
      Theme.fg(theme, :accent, title),
      " ",
      Theme.fg(theme, :border, Widget.repeat(Theme.symbol(theme, :section_line), line_len))
    ]
  end
end
