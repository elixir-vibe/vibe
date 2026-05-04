defmodule Exy.CLI.Commands.Server do
  @moduledoc "CLI `server` command: start, stop, restart, status."
  @behaviour Exy.CLI.Command

  alias Exy.CLI.Server

  @impl true
  def names, do: ["server"]

  @impl true
  def run(["server" | args], opts), do: Server.command(args, opts)
end
