defmodule Vibe.TUI.GhosttySnapshotTest do
  use ExUnit.Case, async: true

  import Ghostty.Test

  alias Vibe.TUI.TerminalLoop

  test "terminal loop output can be captured by Ghostty" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 80, height: 16)
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :h, utf8: "h"})
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :i, utf8: "i"})

    {:ok, terminal} = term(cols: 80, rows: 16)

    loop
    |> TerminalLoop.render()
    |> Enum.intersperse("\r\n")
    |> then(&write(terminal, &1))

    terminal
    |> assert_text("hi")
    |> assert_text("Prompt")
  end
end
