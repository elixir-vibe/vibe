defmodule Vibe.CLI.Commands.Storage do
  @moduledoc "CLI `storage` command: migrate, search, import, vacuum."
  @behaviour Vibe.CLI.Command

  alias Vibe.CLI.Storage

  @impl true
  def names, do: ["storage"]

  @impl true
  def run(["storage" | args], opts), do: Storage.command(args, opts)
end
