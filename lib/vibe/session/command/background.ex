defmodule Vibe.Session.Command.Background do
  @moduledoc "Slash command: /bg — background the current session."
  @behaviour Vibe.Session.Command.Command
  alias Vibe.Session.Command.Spec

  @impl true
  def spec, do: %Spec{name: "bg", aliases: ["background"], description: "Background session"}

  @impl true
  def run(_args, _session_state) do
    {:command, :background_session}
  end
end
