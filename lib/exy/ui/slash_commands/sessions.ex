defmodule Exy.UI.SlashCommands.Sessions do
  @moduledoc false

  @behaviour Exy.UI.SlashCommand

  alias Exy.UI.Event

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
    Exy.Session.list()
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
      seconds < 60 -> "now"
      seconds < 3_600 -> "#{div(seconds, 60)}m"
      seconds < 86_400 -> "#{div(seconds, 3_600)}h"
      seconds < 604_800 -> "#{div(seconds, 86_400)}d"
      true -> "#{div(seconds, 604_800)}w"
    end
  end

  defp relative_time(_at), do: nil
end
