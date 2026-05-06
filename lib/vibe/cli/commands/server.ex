defmodule Vibe.CLI.Commands.Server do
  @moduledoc "CLI `server` command: start, stop, restart, status."
  @behaviour Vibe.CLI.Command

  alias Vibe.CLI.Server

  @impl true
  def names, do: ["server"]

  @impl true
  def run(["server" | args], opts), do: Server.command(args, opts)
end
