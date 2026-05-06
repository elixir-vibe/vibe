defmodule Vibe.CLI.Commands.Search do
  @moduledoc "CLI `search` command: FTS query shortcut."
  @behaviour Vibe.CLI.Command

  alias Vibe.CLI.Storage

  @impl true
  def names, do: ["search"]

  @impl true
  def run(["search" | query_parts], opts), do: Storage.command(["search" | query_parts], opts)
end
