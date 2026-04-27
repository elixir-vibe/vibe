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

  test "starts loader ticks when attaching to an already-working session" do
    session_id = "loader-attach-#{System.unique_integer([:positive])}"
    {:ok, session} = Exy.Session.start_link(session_id: session_id, persist?: false)

    assert :ok =
             Exy.Session.emit_transient_event(
               session,
               Exy.UI.Event.new(:assistant_stream_started, session_id, %{})
             )

    {:ok, _loop} =
      TerminalLoop.start_link(
        output: false,
        width: 60,
        height: 12,
        session_server: session,
        event_target: self()
      )

    assert_receive {TerminalLoop, :event, :loader_tick}, 300
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

    assert_receive {TerminalLoop, :event, %{type: :prompt_submitted}}, 500
    assert_receive {TerminalLoop, :event, %{type: :user_message_added}}, 500
    assert_receive {TerminalLoop, :event, %{type: :assistant_message_added}}, 500
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

  test "confirmation appears above footer like autocomplete without clearing chat history" do
    ask = fn _text, _opts -> {:ok, "ok"} end
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 80, height: 30, ask_fun: ask)

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})
    Process.sleep(50)
    :ok = TerminalLoop.input(loop, "/clear")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter})

    wait_until_render(
      loop,
      &Enum.any?(&1, fn line -> String.contains?(line, "Clear session?") end)
    )

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    footer_index = Enum.find_index(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
    prompt_index = Enum.find_index(plain, &String.contains?(&1, "Prompt"))
    confirmation_index = Enum.find_index(plain, &String.contains?(&1, "Clear session?"))

    assert Enum.any?(plain, &String.contains?(&1, "hello"))
    assert confirmation_index
    assert Enum.any?(plain, &String.contains?(&1, "→ Yes"))
    assert prompt_index == footer_index + 1
    assert confirmation_index < footer_index
  end

  test "keeps footer directly above prompt when autocomplete is visible" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 80, height: 20)

    :ok = TerminalLoop.input(loop, "/se")

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    footer_index = Enum.find_index(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
    prompt_index = Enum.find_index(plain, &String.contains?(&1, "Prompt"))
    autocomplete_index = Enum.find_index(plain, &String.contains?(&1, "/sessions"))

    assert autocomplete_index
    assert footer_index
    assert prompt_index == footer_index + 1
    assert autocomplete_index < footer_index
  end

  defp wait_until_render(loop, fun, deadline \\ System.monotonic_time(:millisecond) + 1_000) do
    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)

    cond do
      fun.(plain) ->
        plain

      System.monotonic_time(:millisecond) < deadline ->
        Process.sleep(10)
        wait_until_render(loop, fun, deadline)

      true ->
        plain
    end
  end

  test "tracks editor cursor position inside the prompt" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12)

    assert TerminalLoop.cursor_position(loop) == {8, 3}
    :ok = TerminalLoop.input(loop, "hello")
    assert TerminalLoop.cursor_position(loop) == {8, 8}
  end

  test "tracks editor cursor position across prompt newlines" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 12)

    :ok = TerminalLoop.input(loop, "hello")
    :ok = TerminalLoop.input_key(loop, %Ghostty.KeyEvent{key: :enter, mods: [:shift]})
    :ok = TerminalLoop.input(loop, "world")

    assert TerminalLoop.cursor_position(loop) == {9, 8}
  end

  test "tracks resize" do
    {:ok, loop} = TerminalLoop.start_link(output: false, width: 60, height: 20)
    assert :ok = TerminalLoop.resize(loop, 100, 30)

    plain = loop |> TerminalLoop.render() |> Enum.map(&Width.visible_text/1)
    assert Enum.any?(plain, &(String.length(&1) <= 100))
  end
end
