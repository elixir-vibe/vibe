defmodule Vibe.CLI.Commands.Sessions do
  @moduledoc "CLI `sessions` command: list and prune sessions."
  @behaviour Vibe.CLI.Command

  alias Vibe.CLI.Sessions

  @impl true
  def names, do: ["sessions", "ls"]

  @impl true
  def run([_command | args], opts), do: Sessions.command(args, opts)
end
