defmodule Vibe.CLI.Commands.Skill do
  @moduledoc "CLI `skill` command: list, show, and manage skills."
  @behaviour Vibe.CLI.Command

  alias Vibe.CLI.Output

  @impl true
  def names, do: ["skill", "skills"]

  @impl true
  def run([_name], opts), do: Output.print({:ok, Vibe.Skill.list()}, opts)

  def run([_name, "list"], opts), do: Output.print({:ok, Vibe.Skill.list()}, opts)

  def run([_name, "show", skill_name], opts), do: Output.print(Vibe.Skill.get(skill_name), opts)

  def run([_name, "apis"], opts), do: Output.print({:ok, Vibe.Skill.apis()}, opts)

  def run([_name, "from-session", session_id, skill_name], opts) do
    Output.print(
      Vibe.Skill.create_from_session(session_id, skill_name, overwrite: opts[:overwrite]),
      opts
    )
  end

  def run(_args, _opts) do
    Output.error("Usage: vibe skill list|show <name>|apis|from-session <session-id> <name>")
    {:error, :invalid_skill_command}
  end
end
