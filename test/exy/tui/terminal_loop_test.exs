defmodule Exy.TUI.TerminalLoopTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{TerminalLoop, Width}

  test "decodes input into app/editor and renders textarea" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)

    assert :ok = TerminalLoop.input(loop, "hello")

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &String.contains?(&1, "hello"))
  end

  test "tracks resize" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)
    assert :ok = TerminalLoop.resize(loop, 100, 30)

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &(String.length(&1) <= 100))
  end
end
