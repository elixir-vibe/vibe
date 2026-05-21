defmodule Vibe.UI.SlashCommands.Attach do
  @moduledoc "Slash command: /attach — switch to an existing session."
  @behaviour Vibe.UI.SlashCommands.Command

  alias Vibe.Event
  alias Vibe.UI.SlashCommands.Sessions
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec, do: %Spec{name: "attach", aliases: ["a"], description: "Attach by session id"}

  @impl true
  def run(args, ui_state) do
    case String.trim(args) do
      "" ->
        Sessions.run("", ui_state)

      session_id ->
        {:events, [Event.new(:session_selected, ui_state.session_id, %{session_id: session_id})]}
    end
  end
end
