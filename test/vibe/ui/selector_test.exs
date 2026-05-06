defmodule Vibe.UI.SelectorTest do
  use ExUnit.Case, async: true

  alias Vibe.UI.{Command, Event, Reducer, State}

  test "opens, moves, and closes selector state" do
    state =
      State.new(session_id: "selector")
      |> Reducer.apply_event(
        Event.new(:selector_opened, "selector", %{
          kind: :model_selector,
          title: "Model",
          items: ["a", "b", "c"]
        })
      )

    assert state.selector.selected == 0
    assert [%{kind: :selector}] = state.overlays

    state = Reducer.apply_event(state, Event.new(:selector_moved, "selector", %{direction: 1}))
    assert state.selector.selected == 1

    state = Reducer.apply_event(state, Event.new(:selector_closed, "selector", %{}))
    assert state.selector == nil
    assert state.overlays == []
  end

  test "sessions slash command opens rich session selector rows" do
    session_id = "selector-row-#{System.unique_integer([:positive])}"

    {:ok, server} =
      Vibe.Session.start_link(
        session_id: session_id,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Vibe.Session.dispatch(server, Command.new(:submit_prompt, %{text: "hello sessions"}))
    Process.sleep(50)

    :ok =
      Vibe.Session.dispatch(
        server,
        Command.new(:slash_command_submitted, %{command: "sessions", args: ""})
      )

    state = Vibe.Session.state(server)

    assert state.selector.kind == :session_selector
    assert Enum.any?(state.selector.items, &match?(%{value: ^session_id}, &1))
  end

  test "slash model command opens a selector" do
    {:ok, server} =
      Vibe.Session.start_link(
        session_id: "selector-session",
        model: "openai_codex:gpt-5.5",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok =
      Vibe.Session.dispatch(
        server,
        Command.new(:slash_command_submitted, %{command: "model", args: ""})
      )

    state = Vibe.Session.state(server)

    assert state.selector.kind == :model_selector
    assert "openai_codex:gpt-5.5" in state.selector.items
  end

  test "selector confirmation updates model" do
    {:ok, server} =
      Vibe.Session.start_link(
        session_id: "selector-model-session",
        model: "old-model",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok =
      Vibe.Session.dispatch(
        server,
        Command.new(:selector_confirmed, %{selector: :model_selector, item: "new-model"})
      )

    assert Vibe.Session.state(server).model == "new-model"
  end

  test "clear slash command asks before clearing visible messages" do
    {:ok, server} =
      Vibe.Session.start_link(
        session_id: "selector-clear-session",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Vibe.Session.dispatch(server, Command.new(:submit_prompt, %{text: "hello"}))
    Process.sleep(50)
    assert Vibe.Session.state(server).messages != []

    :ok =
      Vibe.Session.dispatch(
        server,
        Command.new(:slash_command_submitted, %{command: "clear", args: ""})
      )

    state = Vibe.Session.state(server)
    assert state.messages != []
    assert state.selector.kind == :clear_session_confirmation

    :ok =
      Vibe.Session.dispatch(
        server,
        Command.new(:selector_confirmed, %{selector: :clear_session_confirmation, item: "Yes"})
      )

    assert Vibe.Session.state(server).messages == []
  end
end
