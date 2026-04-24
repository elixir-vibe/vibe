defmodule Exy.TUI.TerminalModeTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.TerminalMode

  test "restore and sane are safe adapters" do
    assert :ok = TerminalMode.restore(nil)
    assert :ok = TerminalMode.sane()
  end
end
