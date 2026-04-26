defmodule Exy.UI.SlashCommands.New do
  @moduledoc false

  @behaviour Exy.UI.SlashCommand

  alias Exy.UI.Event

  @impl true
  def spec, do: %{name: "new", aliases: ["n"], description: "Start a new session"}

  @impl true
  def run(_args, ui_state),
    do: {:events, [Event.new(:session_new_requested, ui_state.session_id, %{})]}
end
