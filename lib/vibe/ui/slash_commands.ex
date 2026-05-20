defmodule Vibe.UI.SlashCommands do
  @moduledoc "Slash command dispatch and autocomplete."
  alias Vibe.UI.Autocomplete
  alias Vibe.UI.Autocomplete.Item
  alias Vibe.UI.Event
  alias Vibe.UI.SlashCommands.Registry

  @spec autocomplete(String.t()) :: Autocomplete.t() | nil
  def autocomplete("/" <> text) do
    query = text |> String.split(~r/\s+/, parts: 2) |> hd()

    items = (Registry.specs() |> Enum.map(&autocomplete_item/1)) ++ skill_autocomplete_items()
    Autocomplete.filter(items, query, title: "Commands", limit: 7)
  end

  def autocomplete(_text), do: nil

  @spec handle(String.t(), String.t(), map()) :: Vibe.UI.SlashCommands.Command.result()
  def handle("skill:" <> skill, args, ui_state),
    do: Vibe.UI.SlashCommands.Skill.run(Enum.join([skill, args], " "), ui_state)

  def handle(command, args, ui_state) do
    case Registry.find(command) do
      nil -> unknown_command(command, ui_state)
      module -> module.run(args, ui_state)
    end
  end

  @spec selector_action(map(), map()) ::
          Vibe.UI.SlashCommands.Command.result() | {:command, String.t()}
  def selector_action(%{selector: selector, item: item}, ui_state) do
    case Registry.find_selector(selector) do
      nil -> :ignore
      module -> run_selector_action(module, item, ui_state)
    end
  end

  def selector_action(_data, _ui_state), do: :ignore

  defp run_selector_action(module, item, ui_state) when is_atom(module),
    do: module.selector_action(item, ui_state)

  defp autocomplete_item(spec) do
    %Item{
      value: "/" <> spec.name,
      label: "/" <> spec.name,
      detail: Map.get(spec, :description),
      group: :slash_command
    }
  end

  defp skill_autocomplete_items do
    Vibe.Skill.list()
    |> Enum.map(fn skill ->
      %Item{
        value: "/skill:" <> skill.name,
        label: "/skill:" <> skill.name,
        detail: Map.get(skill, :title),
        group: :skill
      }
    end)
  end

  defp unknown_command(command, ui_state) do
    {:events,
     [
       Event.new(:notification_added, ui_state.session_id, %{
         level: :warning,
         text: "unknown command: /#{command}"
       })
     ]}
  end
end
