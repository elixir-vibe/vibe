defmodule Vibe.ContextTest do
  use ExUnit.Case, async: true

  test "serialization keeps structured handoff data" do
    events = [
      Vibe.Trajectory.new(:user_message, %{prompt: "Build Vibe"}),
      Vibe.Trajectory.new(:assistant_message, %{result: %{ok: true}}),
      Vibe.Trajectory.new(:tool_call, %{action: :read, path: "lib/vibe.ex"})
    ]

    text = Vibe.Context.serialize(events)
    assert text =~ "[User]: Build Vibe"
    assert text =~ "[Assistant]"
    assert text =~ "[Assistant tool call]"
  end
end
