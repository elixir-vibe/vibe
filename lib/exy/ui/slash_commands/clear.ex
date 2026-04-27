defmodule Exy.UI.SlashCommands.Clear do
  @moduledoc false

  @behaviour Exy.UI.SlashCommands.Command

  alias Exy.UI.Event

  @impl true
  def spec, do: %{name: "clear", description: "Clear visible messages"}

  @impl true
  def run(_args, ui_state),
    do: {:events, [Event.new(:messages_cleared, ui_state.session_id, %{})]}
end
