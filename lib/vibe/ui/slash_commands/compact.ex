defmodule Vibe.UI.SlashCommands.Compact do
  @moduledoc "Slash command: /compact — trigger context compaction."
  @behaviour Vibe.UI.SlashCommands.Command

  @impl true
  def spec, do: %{name: "compact", description: "Compact context"}

  @impl true
  def run(_args, _ui_state), do: :compact
end
