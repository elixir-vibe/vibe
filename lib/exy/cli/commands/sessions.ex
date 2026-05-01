defmodule Exy.CLI.Commands.Sessions do
  @moduledoc "Internal implementation module."
  @behaviour Exy.CLI.Command

  alias Exy.CLI.Sessions

  @impl true
  def names, do: ["sessions", "ls"]

  @impl true
  def run([_command | args], opts), do: Sessions.command(args, opts)
end
