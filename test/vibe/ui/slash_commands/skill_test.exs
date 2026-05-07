defmodule Vibe.UI.SlashCommands.SkillTest do
  use ExUnit.Case, async: false

  alias Vibe.UI.SlashCommands
  alias Vibe.UI.SlashCommands.Skill
  alias Vibe.UI.State

  test "skill commands expand into skill invocation prompt" do
    assert {:command, {:submit_prompt, %{text: text}}} =
             Skill.run("session-to-skill remember this workflow", State.new(session_id: "s1"))

    assert text =~ ~s(<skill name="session-to-skill")
    assert text =~ "References are relative to"
    assert text =~ "remember this workflow"
    refute text =~ "selected skill:"
  end

  test "skill selector submits the selected skill instead of showing a notification" do
    assert {:command, {:submit_prompt, %{text: text}}} =
             Skill.selector_action("session-to-skill", State.new(session_id: "s1"))

    assert text =~ ~s(<skill name="session-to-skill")
    refute text =~ "selected skill:"
  end

  test "autocomplete exposes pi-style skill commands" do
    autocomplete = SlashCommands.autocomplete("/skill:session")

    assert Enum.any?(autocomplete.items, &(&1.value == "/skill:session-to-skill"))
  end
end
