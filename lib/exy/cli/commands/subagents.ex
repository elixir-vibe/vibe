defmodule Exy.CLI.Commands.Subagents do
  @moduledoc "Internal implementation module."
  @behaviour Exy.CLI.Command

  alias Exy.CLI.Subagents

  @impl true
  def names, do: ["subagents", "jobs"]

  @impl true
  def run(["jobs" | args], opts), do: Subagents.command(["jobs" | args], opts)
  def run(["subagents" | args], opts), do: Subagents.command(args, opts)
end
