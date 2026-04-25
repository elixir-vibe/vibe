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
    footer_index = Enum.find_index(plain, &String.contains?(&1, "~/Development/exy"))
    prompt_index = Enum.find_index(plain, &String.contains?(&1, "Prompt"))

    assert length(plain) <= 12
    assert footer_index
    assert prompt_index == footer_index + 1
    assert plain |> Enum.at(footer_index - 1) |> String.trim() == ""
  end

  test "repaints immediately for background UI updates" do
    session_id = "background-ui-#{System.unique_integer([:positive])}"

    {:ok, output} = StringIO.open("")

    {:ok, _loop} =
      TerminalLoop.start_link(output: output, width: 60, height: 12, session_id: session_id)

    assert :ok = Exy.Plugin.UI.set_status(session_id, :indexer, "indexing")
    assert {:ok, contents} = wait_for_output(output, "indexing")
    assert contents =~ "indexing"
  end

  test "loader advances from background ticks without input" do
    session_id = "loader-ui-#{System.unique_integer([:positive])}"

    {:ok, loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 12,
        session_id: session_id,
        event_target: self()
      )

    assert :ok = Exy.UI.Bus.emit(session_id, :assistant_stream_started, %{})
    assert_receive {TerminalLoop, :event, :loader_tick}, 300

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(
             plain,
             &(&1 in ["  ⋰ Thinking…", "  ⋱ Thinking…", "  ✧ Thinking…", "  ✦ Thinking…"])
           )
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

  defp wait_for_output(output, text) do
    deadline = System.monotonic_time(:millisecond) + 500
    do_wait_for_output(output, text, deadline)
  end

  defp do_wait_for_output(output, text, deadline) do
    {_input, contents} = StringIO.contents(output)

    if contents =~ text do
      {:ok, contents}
    else
      remaining = deadline - System.monotonic_time(:millisecond)

      if remaining > 0 do
        Process.sleep(10)
        do_wait_for_output(output, text, deadline)
      else
        {:error, contents}
      end
    end
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
