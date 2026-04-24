defmodule Exy.ContextTest do
  use ExUnit.Case, async: true

  test "serialization keeps structured handoff data" do
    events = [
      Exy.Trajectory.new(:user_message, %{prompt: "Build Exy"}),
      Exy.Trajectory.new(:assistant_message, %{result: %{ok: true}}),
      Exy.Trajectory.new(:tool_call, %{action: :read, path: "lib/exy.ex"})
    ]

    text = Exy.Context.serialize(events)
    assert text =~ "[User]: Build Exy"
    assert text =~ "[Assistant]"
    assert text =~ "[Assistant tool call]"
  end
end
