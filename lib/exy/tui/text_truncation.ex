defmodule Exy.TUI.TextTruncation do
  @moduledoc false

  alias Exy.TUI.Widget

  @type result :: %{lines: [IO.chardata()], omitted: non_neg_integer(), truncated?: boolean()}

  @spec lines([IO.chardata()], keyword()) :: result()
  def lines(lines, opts \\ []) when is_list(lines) do
    enabled? = Keyword.get(opts, :enabled?, true)
    limit = Keyword.get(opts, :limit, 8)

    if enabled? and length(lines) > limit do
      visible = visible_lines(lines, limit, Keyword.get(opts, :mode, :head))
      omitted = length(lines) - limit
      %{lines: visible, omitted: omitted, truncated?: true}
    else
      %{lines: lines, omitted: 0, truncated?: false}
    end
  end

  @spec hint(non_neg_integer(), Exy.TUI.Theme.t(), pos_integer(), keyword()) :: IO.chardata()
  def hint(omitted, theme, width, opts \\ []) do
    label = Keyword.get(opts, :label, "expand")

    [
      Widget.spaces(2),
      Exy.TUI.Theme.fg(theme, :muted, "… (#{omitted} more #{plural(omitted, "line")}, "),
      Exy.TUI.Shortcuts.hint(:toggle_truncation, theme, label: label),
      Exy.TUI.Theme.fg(theme, :muted, ")")
    ]
    |> Widget.fit_line(width)
  end

  defp visible_lines(lines, limit, :tail), do: Enum.take(lines, -limit)
  defp visible_lines(lines, limit, _mode), do: Enum.take(lines, limit)

  defp plural(1, word), do: word
  defp plural(_count, word), do: word <> "s"
end
