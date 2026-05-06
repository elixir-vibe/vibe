defmodule Vibe.TerminalTest do
  use ExUnit.Case, async: false

  test "starts supervised panes" do
    if Code.ensure_loaded?(Ghostty.Terminal) do
      assert {:ok, pane} = Vibe.Terminal.start_pane(pty: false, cols: 20, rows: 5)
      assert :ok = Vibe.Terminal.Pane.write(pane, "supervised")
      assert {:ok, text} = Vibe.Terminal.Pane.snapshot(pane)
      assert text =~ "supervised"
      assert :ok = Vibe.Terminal.Pane.close(pane)
    end
  end
end
