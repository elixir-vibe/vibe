defmodule VibeSkill.SessionToSkill do
  use Vibe.Skill.Script

  skill do
    name "session-to-skill"
    version "0.1.0"
    description "Turn a useful Vibe session into an executable skill draft"
    triggers ["save skill", "create skill", "session to skill", "reusable workflow"]
    alias_as __MODULE__
    examples [
      "SessionToSkill.outline(events)",
      "SessionToSkill.suggest_name(\"Debug Figma variable aliases\")"
    ]
  end

  @moduledoc """
  # Session to Skill

  Use this when a completed session contains a reusable workflow that should be
  preserved as a skill.

  ## Workflow

  1. Identify the durable procedure, not the incidental conversation.
  2. Extract triggers that should activate the skill later.
  3. Write a concise Markdown procedure.
  4. Add Elixir helper functions only when they reduce future model context or
     make verification deterministic.
  5. Keep generated skills trusted-local; review `.exs` code before sharing.

  ## CLI

      vibe skill from-session <session-id> <skill-name>

  ## Eval helpers

      SessionToSkill.suggest_name("Debug Figma variable aliases")
      SessionToSkill.outline(["step one", "step two"])
  """

  def suggest_name(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 60)
  end

  def outline(items) when is_list(items) do
    items
    |> Enum.map_join("\n", fn item -> "- " <> to_string(item) end)
  end
end
