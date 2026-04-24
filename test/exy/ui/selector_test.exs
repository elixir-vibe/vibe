defmodule Exy.UI.SelectorTest do
  use ExUnit.Case, async: true

  alias Exy.UI.{Command, Event, Reducer, State}

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

  test "slash model command opens a selector" do
    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: "selector-session",
        model: "openai_codex:gpt-5.5",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok =
      Exy.UI.SessionServer.dispatch(
        server,
        Command.new(:slash_command_submitted, %{command: "model", args: ""})
      )

    state = Exy.UI.SessionServer.state(server)

    assert state.selector.kind == :model_selector
    assert state.selector.items == ["openai_codex:gpt-5.5"]
  end

  test "selector confirmation updates model" do
    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: "selector-model-session",
        model: "old-model",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok =
      Exy.UI.SessionServer.dispatch(
        server,
        Command.new(:selector_confirmed, %{selector: :model_selector, item: "new-model"})
      )

    assert Exy.UI.SessionServer.state(server).model == "new-model"
  end

  test "clear slash command clears visible messages" do
    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: "selector-clear-session",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Exy.UI.SessionServer.dispatch(server, Command.new(:submit_prompt, %{text: "hello"}))
    Process.sleep(50)
    assert Exy.UI.SessionServer.state(server).messages != []

    :ok =
      Exy.UI.SessionServer.dispatch(
        server,
        Command.new(:slash_command_submitted, %{command: "clear", args: ""})
      )

    assert Exy.UI.SessionServer.state(server).messages == []
  end
end
