defmodule Exy.UI.SlashCommands do
  @moduledoc false

  alias Exy.UI.Autocomplete
  alias Exy.UI.Event
  alias Exy.UI.SlashCommands.Registry

  @spec autocomplete(String.t()) :: Autocomplete.t() | nil
  def autocomplete("/" <> text) do
    query = text |> String.split(~r/\s+/, parts: 2) |> hd()

    Registry.specs()
    |> Enum.map(&autocomplete_item/1)
    |> Autocomplete.filter(query, title: "Commands", limit: 7)
  end

  def autocomplete(_text), do: nil

  @spec handle(String.t(), String.t(), map()) :: Exy.UI.SlashCommand.result()
  def handle(command, args, ui_state) do
    case Registry.find(command) do
      nil -> unknown_command(command, ui_state)
      module -> module.run(args, ui_state)
    end
  end

  @spec selector_action(map(), map()) :: Exy.UI.SlashCommand.result() | {:command, String.t()}
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
    %{
      value: "/" <> spec.name,
      label: "/" <> spec.name,
      detail: Map.get(spec, :description),
      group: :slash_command
    }
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
