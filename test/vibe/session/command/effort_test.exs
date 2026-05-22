defmodule Vibe.Session.Command.EffortTest do
  use ExUnit.Case, async: true

  alias Vibe.Session.Command.Effort
  alias Vibe.UI.State

  test "opens selector through semantic command" do
    assert Effort.run("", State.new(session_id: "s1")) == {:command, :open_effort_selector}
  end

  test "selects effort from boundary string through semantic command" do
    assert Effort.run("high", State.new(session_id: "s1")) ==
             {:command, {:select_effort, %{effort: :high}}}
  end

  test "rejects unknown effort through notification command" do
    assert Effort.run("loud", State.new(session_id: "s1")) ==
             {:command, {:notification_added, %{level: :warning, text: "unknown effort: loud"}}}
  end
end
