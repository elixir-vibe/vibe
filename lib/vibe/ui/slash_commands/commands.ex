defmodule Vibe.UI.SlashCommands.Commands do
  @moduledoc "Slash command: /commands — list available slash commands."
  @behaviour Vibe.UI.SlashCommands.Command

  alias Vibe.UI.Event
  alias Vibe.UI.Selector
  alias Vibe.UI.SlashCommands.Spec
  alias Vibe.UI.SlashCommands.Registry

  @impl true
  def spec,
    do: %Spec{
      name: "commands",
      description: "Open command palette",
      selectors: [:command_palette]
    }

  def command_selector, do: :command_palette

  @impl true
  def run(_args, ui_state) do
    selector = %Selector{
      kind: :command_palette,
      title: "Commands",
      items: Enum.map(Registry.specs(), &("/" <> &1.name)),
      selected: 0,
      limit: 8
    }

    {:events, [Event.new(:selector_opened, ui_state.session_id, selector)]}
  end

  @impl true
  def selector_action("/" <> command, _ui_state), do: {:command, command}
  def selector_action(command, _ui_state) when is_binary(command), do: {:command, command}
  def selector_action(_item, _ui_state), do: :ignore
end
