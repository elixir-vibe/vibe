defmodule Exy.UI.SlashCommands do
  @moduledoc false

  alias Exy.UI.Event

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

  defp selector("session", _ui_state) do
    items = Exy.Session.Store.list() |> Enum.map(& &1.id)
    %{kind: :session_selector, title: "Session", items: items, selected: 0, limit: 8}
  end

  defp selector("skill", _ui_state) do
    items = Exy.Skill.list() |> Enum.map(& &1.name)
    %{kind: :skill_selector, title: "Skill", items: items, selected: 0, limit: 8}
  end

  defp selector("commands", _ui_state) do
    %{
      kind: :command_palette,
      title: "Commands",
      items: ["model", "session", "skill", "clear", "compact"],
      selected: 0,
      limit: 8
    }
  end

  defp selector(_command, _ui_state), do: nil
end
