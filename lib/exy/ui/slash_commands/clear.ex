defmodule Exy.UI.SlashCommands.Clear do
  @moduledoc "Internal implementation module."
  @behaviour Exy.UI.SlashCommands.Command

  alias Exy.UI.Event

  @impl true
  def spec,
    do: %{
      name: "clear",
      description: "Clear visible messages",
      selectors: [:clear_session_confirmation]
    }

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
