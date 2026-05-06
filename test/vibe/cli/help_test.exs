defmodule Vibe.CLI.HelpTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  test "prints built-in help index" do
    output =
      capture_io(fn ->
        assert :ok = Vibe.CLI.Command.dispatch(%{args: ["help"], opts: [], invalid: []})
      end)

    assert output =~ "# Vibe help"
    assert output =~ "quickstart"
  end

  test "prints a built-in help topic" do
    output =
      capture_io(fn ->
        assert :ok = Vibe.CLI.Command.dispatch(%{args: ["help", "eval"], opts: [], invalid: []})
      end)

    assert output =~ "# Eval"
    assert output =~ "Cmd.run"
  end
end
