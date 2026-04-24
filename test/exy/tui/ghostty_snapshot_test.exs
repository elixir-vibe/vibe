defmodule Exy.TUI.GhosttySnapshotTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.TerminalLoop

  test "terminal loop output can be captured by Ghostty" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 80, height: 16)
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :h, utf8: "h"})
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :i, utf8: "i"})

    {:ok, terminal} = Ghostty.Terminal.start_link(cols: 80, rows: 16)

    loop
    |> TerminalLoop.render()
    |> Enum.intersperse("\r\n")
    |> then(&Ghostty.Terminal.write(terminal, &1))

    {:ok, plain} = Ghostty.Terminal.snapshot(terminal, :plain)
    assert plain =~ "hi"
    assert plain =~ "Prompt"
  end
end
