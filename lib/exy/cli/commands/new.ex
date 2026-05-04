defmodule Exy.CLI.Commands.New do
  @moduledoc "CLI `new` command: create a fresh server session."
  @behaviour Exy.CLI.Command

  alias Exy.CLI.Sessions

  @impl true
  def names, do: ["new", "n"]

  @impl true
  def run([_command | _args], opts) do
    if opts[:print] == true or opts[:mode] == "json",
      do: Sessions.new(opts),
      else: Sessions.new_tui(opts)
  end
end
