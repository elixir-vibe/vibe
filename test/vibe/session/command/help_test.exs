defmodule Vibe.Session.Command.HelpTest do
  use ExUnit.Case, async: true

  alias Vibe.Session.Command, as: SlashCommands
  alias Vibe.UI.State

  test "help command is registered" do
    assert SlashCommands.Registry.find("help") == SlashCommands.Help
    assert SlashCommands.Registry.find("docs") == SlashCommands.Help
  end

  test "returns notification event with docs markdown" do
    session_state = %State{session_id: "help-test"}

    assert {:events, [event]} = SlashCommands.Help.run(["eval"], session_state)
    assert event.type == :notification_added
    assert event.session_id == "help-test"
    assert event.data.text =~ "# Eval"
  end
end
