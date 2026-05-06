defmodule Vibe.TUI.DurationTest do
  use ExUnit.Case, async: true

  test "formats positive millisecond durations for compact tool headers" do
    assert Vibe.TUI.Duration.milliseconds(1000) == "1s"
    assert Vibe.TUI.Duration.milliseconds(1500) == "1.5s"
    assert Vibe.TUI.Duration.milliseconds(0) == nil
    assert Vibe.TUI.Duration.milliseconds(nil) == nil
  end
end
