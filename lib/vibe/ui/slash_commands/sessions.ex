defmodule Vibe.UI.SlashCommands.Sessions do
  @moduledoc "Slash command: /sessions — list active sessions."
  @behaviour Vibe.UI.SlashCommands.Command

  alias Vibe.UI.Event

  @seconds_per_minute 60
  @seconds_per_hour 3_600
  @seconds_per_day 86_400
  @seconds_per_week 604_800

  @impl true
  def spec,
    do: %{
      name: "sessions",
      aliases: ["session", "s"],
      description: "Browse stored sessions",
      selectors: [:session_selector]
    }

  @impl true
  def run(_args, ui_state) do
    selector = %{
      kind: :session_selector,
      title: "Sessions",
      items: session_items(),
      selected: 0,
      limit: 10
    }

    {:events, [Event.new(:selector_opened, ui_state.session_id, selector)]}
  end

  @impl true
  def selector_action(%{value: session_id}, ui_state) when is_binary(session_id),
    do: {:events, [Event.new(:session_selected, ui_state.session_id, %{session_id: session_id})]}

  def selector_action(session_id, ui_state) when is_binary(session_id),
    do: {:events, [Event.new(:session_selected, ui_state.session_id, %{session_id: session_id})]}

  def selector_action(_item, _ui_state), do: :ignore

  defp session_items do
    Vibe.Session.list()
    |> Enum.map(fn session ->
      %{
        value: session.id,
        label: session_label(session),
        detail: session_detail(session),
        session: session
      }
    end)
  end

  defp session_label(session) do
    preview =
      Map.get(session, :first_message) || Map.get(session, :last_message_preview) ||
        "empty session"

    marker = if Map.get(session, :live?), do: "● ", else: "  "
    marker <> preview
  end

  defp session_detail(session) do
    [
      short_id(Map.get(session, :id)),
      relative_time(Map.get(session, :updated_at)),
      message_count(Map.get(session, :message_count))
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("  ")
  end

  defp short_id(id) when is_binary(id), do: String.slice(id, 0, 15)
  defp short_id(_id), do: nil

  defp message_count(count) when is_integer(count), do: "#{count} msg"
  defp message_count(_count), do: nil

  defp relative_time(%DateTime{} = at) do
    seconds = max(DateTime.diff(DateTime.utc_now(), at), 0)

    cond do
      seconds < @seconds_per_minute -> "now"
      seconds < @seconds_per_hour -> "#{div(seconds, @seconds_per_minute)}m"
      seconds < @seconds_per_day -> "#{div(seconds, @seconds_per_hour)}h"
      seconds < @seconds_per_week -> "#{div(seconds, @seconds_per_day)}d"
      true -> "#{div(seconds, @seconds_per_week)}w"
    end
  end

  defp relative_time(_at), do: nil
end
