defmodule Vibe.UI.SlashCommands.Compact do
  @moduledoc "Slash command: /compact — trigger context compaction."
  @behaviour Vibe.UI.SlashCommands.Command
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec, do: %Spec{name: "compact", description: "Compact context"}

  @impl true
  def run(_args, _ui_state), do: :compact
end
