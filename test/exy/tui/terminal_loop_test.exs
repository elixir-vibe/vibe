defmodule Exy.TUI.TerminalLoopTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{TerminalLoop, Width}

  test "decodes input into app/editor and renders textarea" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)

    assert :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :h, utf8: "h"})
    assert :ok = TerminalLoop.input(loop, "ello")

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &String.contains?(&1, "hello"))
  end

  test "keeps editor visible in a bounded viewport" do
    ask = fn text, _opts -> {:ok, Enum.map_join(1..20, "\n", &"line #{&1}: #{text}")} end
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12, ask_fun: ask)

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})
    Process.sleep(50)

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert length(plain) <= 12
    assert Enum.any?(plain, &String.contains?(&1, "Prompt"))
  end

  test "notifies event target for asynchronous UI updates" do
    ask = fn _text, _opts -> {:ok, "done"} end

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 12,
        ask_fun: ask,
        event_target: self()
      )

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})

    assert_receive {TerminalLoop, :event, %{type: :prompt_submitted}}, 100
    assert_receive {TerminalLoop, :event, %{type: :user_message_added}}, 100
    assert_receive {TerminalLoop, :event, %{type: :assistant_message_added}}, 100
  end

  test "tracks editor cursor position inside the prompt" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12)

    assert TerminalLoop.cursor_position(loop) == {8, 3}
    :ok = TerminalLoop.input(loop, "hello")
    assert TerminalLoop.cursor_position(loop) == {8, 8}
  end

  test "tracks resize" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)
    assert :ok = TerminalLoop.resize(loop, 100, 30)

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &(String.length(&1) <= 100))
  end
end
