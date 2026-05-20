defmodule Vibe.UI.SlashCommands.Spec do
  @moduledoc "Slash command metadata contract."

  defstruct [:name, :description, aliases: [], selectors: []]
end
