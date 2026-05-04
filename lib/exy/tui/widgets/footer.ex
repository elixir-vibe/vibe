defmodule Exy.TUI.Widgets.Footer do
  @moduledoc "TUI widget: status bar with model, usage, and session info."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    usage = Map.get(props, :usage, %{}) || %{}
    tokens = Map.get(usage, :total_tokens, 0)
    separator = Theme.symbol(theme, :separator)

    left = [
      short_cwd(Map.get(props, :cwd)),
      separator,
      short_session_id(Map.get(props, :session_id), width)
    ]

    right = [
      to_string(Map.get(props, :model)),
      separator,
      effort_label(Map.get(props, :effort)),
      separator,
      to_string(Map.get(props, :status)),
      separator,
      sessions_label(Map.get(props, :active_sessions)),
      separator,
      to_string(tokens),
      " tok"
    ]

    footer = Theme.fg(theme, :dim, Widget.join_sides(left, right, width))

    case plugin_status_line(Map.get(props, :plugin_statuses, %{}), width, theme) do
      nil -> [footer]
      status_line -> [footer, status_line]
    end
  end

  defp short_session_id(session_id, width) do
    session_id
    |> to_string()
    |> Widget.fit_line(max(div(width, 4), 12))
  end

  defp effort_label(effort) when effort in [:off, :minimal, :low, :medium, :high, :xhigh],
    do: Atom.to_string(effort)

  defp effort_label(nil), do: "off"
  defp effort_label(effort), do: to_string(effort)

  defp sessions_label(nil), do: "local"
  defp sessions_label(1), do: "1 active"
  defp sessions_label(count), do: "#{count} active"

  defp plugin_status_line(statuses, _width, _theme) when map_size(statuses) == 0, do: nil

  defp plugin_status_line(statuses, width, theme) do
    line =
      statuses
      |> Enum.sort_by(fn {key, _text} -> to_string(key) end)
      |> Enum.map_join(" ", fn {_key, text} -> sanitize_status_text(text) end)
      |> Widget.fit_line(width)

    Theme.fg(theme, :dim, line)
  end

  defp sanitize_status_text(text) do
    text
    |> to_string()
    |> String.replace(~r/[\r\n\t]/, " ")
    |> String.replace(~r/ +/, " ")
    |> String.trim()
  end

  defp short_cwd(nil), do: ""

  defp short_cwd(cwd) do
    home = System.user_home!()

    if String.starts_with?(cwd, home), do: "~" <> String.replace_prefix(cwd, home, ""), else: cwd
  end
end
