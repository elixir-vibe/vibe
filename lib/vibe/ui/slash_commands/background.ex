defmodule Vibe.UI.SlashCommands.Background do
  @moduledoc "Slash command: /bg — background the current session."
  @behaviour Vibe.UI.SlashCommands.Command

  @impl true
  def spec, do: %{name: "bg", aliases: ["background"], description: "Background session"}

  @impl true
  def run(_args, _ui_state) do
    {:command, :background_session}
  end
end
