defmodule Vibe.Session.Command.Attach do
  @moduledoc "Slash command: /attach — switch to an existing session."
  @behaviour Vibe.Session.Command.Command

  alias Vibe.Event
  alias Vibe.Session.Command.Sessions
  alias Vibe.Session.Command.Spec

  @impl true
  def spec, do: %Spec{name: "attach", aliases: ["a"], description: "Attach by session id"}

  @impl true
  def run(args, session_state) do
    case String.trim(args) do
      "" ->
        Sessions.run("", session_state)

      session_id ->
        {:events,
         [Event.new(:session_selected, session_state.session_id, %{session_id: session_id})]}
    end
  end
end
