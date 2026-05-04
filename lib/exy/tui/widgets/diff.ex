defmodule Exy.TUI.Widgets.Diff do
  @moduledoc "TUI widget: colored unified diff display."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    props
    |> diff_lines(theme)
    |> Enum.flat_map(&Widget.wrap(&1, width))
  end

  defp diff_lines(props) do
    cond do
      Map.has_key?(props, :lines) -> props.lines
      Map.has_key?(props, :text) -> String.split(props.text, "\n")
      true -> []
    end
  end

  defp diff_lines(props, theme),
    do: props |> diff_lines() |> Enum.map(&style_diff_line(&1, theme))

  defp style_diff_line({:add, line}, theme), do: Theme.fg(theme, :success, ["+", line])
  defp style_diff_line({:del, line}, theme), do: Theme.fg(theme, :error, ["-", line])
  defp style_diff_line({:context, line}, theme), do: Theme.fg(theme, :dim, [" ", line])
  defp style_diff_line("+" <> _rest = line, theme), do: Theme.fg(theme, :success, line)
  defp style_diff_line("-" <> _rest = line, theme), do: Theme.fg(theme, :error, line)
  defp style_diff_line(line, theme), do: Theme.fg(theme, :dim, line)
end
