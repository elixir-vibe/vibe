defmodule Vibe.Session.Command.New do
  @moduledoc "Slash command: /new — start a fresh session."
  @behaviour Vibe.Session.Command.Command

  alias Vibe.Event
  alias Vibe.Session.Command.Spec

  @impl true
  def spec, do: %Spec{name: "new", aliases: ["n"], description: "Start a new session"}

  @impl true
  def run(_args, session_state),
    do:
      {:events,
       [
         Event.new(
           :session_new_requested,
           session_state.session_id,
           Vibe.Event.Session.new_requested()
         )
       ]}
end
