defmodule Vibe.Session.Command.Clear do
  @moduledoc "Slash command: /clear — reset session history."
  @behaviour Vibe.Session.Command.Command

  alias Vibe.Event
  alias Vibe.Session.Command.Spec

  @impl true
  def spec,
    do: %Spec{
      name: "clear",
      description: "Clear visible messages",
      selectors: [:clear_session_confirmation]
    }

  def confirmation_selector, do: :clear_session_confirmation

  @impl true
  def run(_args, session_state) do
    {:events,
     [
       Event.new(
         :confirmation_requested,
         session_state.session_id,
         Vibe.Event.Surface.confirmation_requested(%{
           kind: :clear_session_confirmation,
           title: "Clear session?",
           message: "This will delete all messages in the current session.",
           confirm: "Yes",
           cancel: "No"
         })
       )
     ]}
  end

  @impl true
  def selector_action("Yes", session_state),
    do:
      {:events,
       [Event.new(:messages_cleared, session_state.session_id, Vibe.Event.Message.cleared())]}

  def selector_action(_item, _session_state), do: :ignore
end
