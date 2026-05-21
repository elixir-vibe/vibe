defmodule Vibe.TUI.Widgets.Footer do
  @moduledoc "TUI widget: status bar with model, usage, and session info."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.{Theme, Widget}

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

    effort = Map.get(props, :effort)

    right = [
      to_string(Map.get(props, :model)),
      separator,
      effort_label(effort, theme),
      separator,
      to_string(Map.get(props, :status)),
      separator,
      sessions_label(Map.get(props, :active_sessions)),
      separator,
      to_string(tokens),
      " tok"
    ]

    footer = Theme.fg(theme, :dim, Widget.join_sides(left, right, width))

    [footer]
    |> append_optional(goal_line(Map.get(props, :goal), width, theme))
    |> append_optional(runtime_alerts_line(Map.get(props, :runtime_alerts, []), width, theme))
    |> append_optional(plugin_status_line(Map.get(props, :plugin_statuses, %{}), width, theme))
  end

  defp short_session_id(session_id, width) do
    session_id
    |> to_string()
    |> Widget.fit_line(max(div(width, 4), 12))
  end

  defp effort_label(effort, theme)
       when effort in [:off, :minimal, :low, :medium, :high, :xhigh] do
    Theme.fg(theme, effort_color(effort), Atom.to_string(effort))
  end

  defp effort_label(nil, theme), do: Theme.fg(theme, :dim, "off")
  defp effort_label(effort, theme), do: Theme.fg(theme, :muted, to_string(effort))

  defp effort_color(:off), do: :dim
  defp effort_color(:minimal), do: :muted
  defp effort_color(:low), do: :success
  defp effort_color(:medium), do: :accent
  defp effort_color(:high), do: :warning
  defp effort_color(:xhigh), do: :error

  defp sessions_label(nil), do: "local"
  defp sessions_label(1), do: "1 active"
  defp sessions_label(count), do: "#{count} active"

  defp append_optional(lines, nil), do: lines
  defp append_optional(lines, line), do: [line | Enum.reverse(lines)] |> Enum.reverse()

  defp goal_line(nil, _width, _theme), do: nil

  defp goal_line(goal, width, theme) do
    status = goal.status |> Atom.to_string() |> String.replace("_", " ")
    line = "Goal #{status}: #{goal.objective}" |> Widget.fit_line(width)
    Theme.fg(theme, :accent, line)
  end

  defp runtime_alerts_line([], _width, _theme), do: nil

  defp runtime_alerts_line(alerts, width, theme) do
    line =
      Enum.map_join(alerts, " · ", &alert_label/1)
      |> Widget.fit_line(width)

    Theme.fg(theme, :warning, line)
  end

  defp alert_label(%{type: :disk_almost_full, message: message}), do: "disk low: #{message}"
  defp alert_label(%{type: :system_memory_high_watermark}), do: "memory pressure"
  defp alert_label(%{title: title}), do: title
  defp alert_label(alert), do: inspect(alert)

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
