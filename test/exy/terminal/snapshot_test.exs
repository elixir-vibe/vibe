defmodule Exy.Terminal.SnapshotTest do
  use ExUnit.Case, async: true

  test "converts ANSI output to terminal-aware plain text" do
    if Code.ensure_loaded?(Ghostty.Terminal) do
      assert {:ok, snapshot} =
               Exy.Terminal.Snapshot.from_ansi("\e[31mred\e[0m\r\n", cols: 20, rows: 5)

      assert snapshot.plain =~ "red"
      assert is_binary(snapshot.html)
      assert is_list(snapshot.cells)
    else
      assert {:ok, snapshot} = Exy.Terminal.Snapshot.from_ansi("plain")
      assert snapshot.plain == "plain"
    end
  end
end
