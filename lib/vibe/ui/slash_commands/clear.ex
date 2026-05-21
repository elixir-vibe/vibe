defmodule Vibe.UI.SlashCommands.Clear do
  @moduledoc "Slash command: /clear — reset session history."
  @behaviour Vibe.UI.SlashCommands.Command

  alias Vibe.Event
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec,
    do: %Spec{
      name: "clear",
      description: "Clear visible messages",
      selectors: [:clear_session_confirmation]
    }

  def confirmation_selector, do: :clear_session_confirmation

  @impl true
  def run(_args, ui_state) do
    {:events,
     [
       Event.new(:confirmation_requested, ui_state.session_id, %{
         kind: :clear_session_confirmation,
         title: "Clear session?",
         message: "This will delete all messages in the current session.",
         confirm: "Yes",
         cancel: "No"
       })
     ]}
  end

  @impl true
  def selector_action("Yes", ui_state),
    do: {:events, [Event.new(:messages_cleared, ui_state.session_id, %{})]}

  def selector_action(_item, _ui_state), do: :ignore
end
