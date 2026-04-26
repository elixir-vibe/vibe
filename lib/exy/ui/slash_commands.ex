defmodule Exy.UI.SlashCommands do
  @moduledoc false

  alias Exy.UI.Autocomplete
  alias Exy.UI.Event

  @commands [
    %{value: "/sessions", label: "/sessions", detail: "Browse and resume stored sessions"},
    %{value: "/session", label: "/session", detail: "Browse stored sessions"},
    %{value: "/model", label: "/model", detail: "Choose model"},
    %{value: "/skill", label: "/skill", detail: "Choose skill"},
    %{value: "/clear", label: "/clear", detail: "Clear visible messages"},
    %{value: "/compact", label: "/compact", detail: "Compact context"},
    %{value: "/commands", label: "/commands", detail: "Open command palette"}
  ]

  @spec autocomplete(String.t()) :: Autocomplete.t() | nil
  def autocomplete("/" <> text) do
    query = text |> String.split(~r/\s+/, parts: 2) |> hd()
    Autocomplete.filter(@commands, query, title: "Commands", limit: 7)
  end

  def autocomplete(_text), do: nil

  @spec handle(String.t(), String.t(), map()) :: {:events, [Event.t()]} | :compact
  def handle("clear", _args, ui_state),
    do: {:events, [Event.new(:messages_cleared, ui_state.session_id, %{})]}

  def handle("compact", _args, _ui_state), do: :compact

  def handle(command, _args, ui_state) do
    case selector(command, ui_state) do
      nil ->
        {:events,
         [
           Event.new(:notification_added, ui_state.session_id, %{
             level: :warning,
             text: "unknown command: /#{command}"
           })
         ]}

      selector ->
        {:events, [Event.new(:selector_opened, ui_state.session_id, selector)]}
    end
  end

  @spec selector_action(map(), map()) :: {:events, [Event.t()]} | {:command, String.t()} | :ignore
  def selector_action(%{selector: :model_selector, item: model}, ui_state)
      when is_binary(model) do
    {:events, [Event.new(:model_selected, ui_state.session_id, %{model: model})]}
  end

  def selector_action(%{selector: :session_selector, item: %{value: session_id}}, ui_state)
      when is_binary(session_id) do
    {:events, [Event.new(:session_selected, ui_state.session_id, %{session_id: session_id})]}
  end

  def selector_action(%{selector: :session_selector, item: session_id}, ui_state)
      when is_binary(session_id) do
    {:events, [Event.new(:session_selected, ui_state.session_id, %{session_id: session_id})]}
  end

  def selector_action(%{selector: :skill_selector, item: skill}, ui_state)
      when is_binary(skill) do
    {:events,
     [
       Event.new(:notification_added, ui_state.session_id, %{
         level: :info,
         text: "selected skill: #{skill}"
       })
     ]}
  end

  def selector_action(%{selector: :command_palette, item: command}, _ui_state)
      when is_binary(command),
      do: {:command, command}

  def selector_action(_data, _ui_state), do: :ignore

  defp selector("model", ui_state) do
    %{kind: :model_selector, title: "Model", items: [ui_state.model], selected: 0, limit: 8}
  end

  defp selector(command, _ui_state) when command in ["session", "sessions", "s"] do
    items =
      Exy.Session.list()
      |> Enum.map(fn session ->
        %{
          value: session.id,
          label: session_label(session),
          detail: session_detail(session),
          session: session
        }
      end)

    %{kind: :session_selector, title: "Sessions", items: items, selected: 0, limit: 10}
  end

  defp selector("skill", _ui_state) do
    items = Exy.Skill.list() |> Enum.map(& &1.name)
    %{kind: :skill_selector, title: "Skill", items: items, selected: 0, limit: 8}
  end

  defp selector("commands", _ui_state) do
    %{
      kind: :command_palette,
      title: "Commands",
      items: Enum.map(@commands, & &1.value),
      selected: 0,
      limit: 8
    }
  end

  defp selector(_command, _ui_state), do: nil

  defp session_label(session) do
    preview = session.first_message || session.last_message_preview || "empty session"
    marker = if Map.get(session, :live?), do: "● ", else: "  "
    marker <> preview
  end

  defp session_detail(session) do
    [
      short_id(session.id),
      relative_time(session.updated_at),
      message_count(session.message_count)
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
