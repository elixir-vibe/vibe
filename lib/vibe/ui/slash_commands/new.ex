defmodule Vibe.UI.SlashCommands.New do
  @moduledoc "Slash command: /new — start a fresh session."
  @behaviour Vibe.UI.SlashCommands.Command

  alias Vibe.Event
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec, do: %Spec{name: "new", aliases: ["n"], description: "Start a new session"}

  @impl true
  def run(_args, ui_state),
    do: {:events, [Event.new(:session_new_requested, ui_state.session_id, %{})]}
end
