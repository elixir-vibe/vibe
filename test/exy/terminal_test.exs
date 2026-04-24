defmodule Exy.TerminalTest do
  use ExUnit.Case, async: false

  test "starts supervised panes" do
    if Code.ensure_loaded?(Ghostty.Terminal) do
      assert {:ok, pane} = Exy.Terminal.start_pane(pty: false, cols: 20, rows: 5)
      assert :ok = Exy.Terminal.Pane.write(pane, "supervised")
      assert {:ok, text} = Exy.Terminal.Pane.snapshot(pane)
      assert text =~ "supervised"
      assert :ok = Exy.Terminal.Pane.close(pane)
    end
  end
end
