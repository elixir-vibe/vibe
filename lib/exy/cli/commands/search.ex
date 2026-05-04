defmodule Exy.CLI.Commands.Search do
  @moduledoc "CLI `search` command: FTS query shortcut."
  @behaviour Exy.CLI.Command

  alias Exy.CLI.Storage

  @impl true
  def names, do: ["search"]

  @impl true
  def run(["search" | query_parts], opts), do: Storage.command(["search" | query_parts], opts)
end
