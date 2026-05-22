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
    capture_io(:stderr, fn ->
      assert {:error, {:server_not_running, _reason}} =
               Vibe.CLI.Commands.Default.run([], bg: true, server_start_timeout_ms: 0)
    end)
  end
end
