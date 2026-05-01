defmodule Exy.CLI.Commands.Storage do
  @moduledoc "Internal implementation module."
  @behaviour Exy.CLI.Command

  alias Exy.CLI.Storage

  @impl true
  def names, do: ["storage"]

  @impl true
  def run(["storage" | args], opts), do: Storage.command(args, opts)
end
