defmodule Exy.Terminal.PaneTest do
  use ExUnit.Case, async: false

  test "writes directly to a Ghostty terminal when PTY is disabled" do
    if Code.ensure_loaded?(Ghostty.Terminal) do
      assert {:ok, pane} = Exy.Terminal.Pane.start_link(pty: false, cols: 20, rows: 5)
      assert :ok = Exy.Terminal.Pane.write(pane, "hello")
      assert {:ok, plain} = Exy.Terminal.Pane.snapshot(pane)
      assert plain =~ "hello"
      assert :ok = Exy.Terminal.Pane.close(pane)
    end
  end
end
