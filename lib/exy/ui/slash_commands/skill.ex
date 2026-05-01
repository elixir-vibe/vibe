defmodule Exy.UI.SlashCommands.Skill do
  @moduledoc "Internal implementation module."
  @behaviour Exy.UI.SlashCommands.Command

  alias Exy.UI.Event

  @impl true
  def spec, do: %{name: "skill", description: "Choose skill", selectors: [:skill_selector]}

  @impl true
  def run(_args, ui_state) do
    selector = %{
      kind: :skill_selector,
      title: "Skill",
      items: Exy.Skill.list() |> Enum.map(& &1.name),
      selected: 0,
      limit: 8
    }

    {:events, [Event.new(:selector_opened, ui_state.session_id, selector)]}
  end

  @impl true
  def selector_action(skill, ui_state) when is_binary(skill) do
    {:events,
     [
       Event.new(:notification_added, ui_state.session_id, %{
         level: :info,
         text: "selected skill: #{skill}"
       })
     ]}
  end

  def selector_action(_item, _ui_state), do: :ignore
end
