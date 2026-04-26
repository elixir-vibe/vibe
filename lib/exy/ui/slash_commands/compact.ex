defmodule Exy.UI.SlashCommands.Compact do
  @moduledoc false

  @behaviour Exy.UI.SlashCommand

  @impl true
  def spec, do: %{name: "compact", description: "Compact context"}

  @impl true
  def run(_args, _ui_state), do: :compact
end
