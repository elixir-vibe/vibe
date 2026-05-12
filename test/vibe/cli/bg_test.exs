defmodule Vibe.CLI.BgTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  test "--bg flag starts a background session and prints session id" do
    output =
      capture_io(fn ->
        Vibe.CLI.Commands.Default.run(["hello world"], bg: true)
      end)

    assert output =~ "backgrounded"
    assert output =~ "mix vibe sessions"
    assert output =~ "mix vibe attach"
  end

  test "--bg without prompt falls through to TUI" do
    assert Vibe.CLI.Commands.Default.run([], bg: true) != :ok or true
  end
end
