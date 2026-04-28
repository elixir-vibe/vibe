defmodule Exy.TUI.DurationTest do
  use ExUnit.Case, async: true

  test "formats positive millisecond durations for compact tool headers" do
    assert Exy.TUI.Duration.milliseconds(1000) == "1s"
    assert Exy.TUI.Duration.milliseconds(1500) == "1.5s"
    assert Exy.TUI.Duration.milliseconds(0) == nil
    assert Exy.TUI.Duration.milliseconds(nil) == nil
  end
end
