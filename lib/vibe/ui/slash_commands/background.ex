defmodule Vibe.UI.SlashCommands.Background do
  @moduledoc "Slash command: /bg — background the current session."
  @behaviour Vibe.UI.SlashCommands.Command
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec, do: %Spec{name: "bg", aliases: ["background"], description: "Background session"}

  @impl true
  def run(_args, _ui_state) do
    {:command, :background_session}
  end
end
