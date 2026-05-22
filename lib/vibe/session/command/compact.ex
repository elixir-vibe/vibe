defmodule Vibe.Session.Command.Compact do
  @moduledoc "Slash command: /compact — trigger context compaction."
  @behaviour Vibe.Session.Command.Command
  alias Vibe.Session.Command.Spec

  @impl true
  def spec, do: %Spec{name: "compact", description: "Compact context"}

  @impl true
  def run(_args, _session_state), do: :compact
end
