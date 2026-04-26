defmodule Exy.TUI.Views.ChatTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{Theme, Width}
  alias Exy.TUI.Views.Chat
  alias Exy.UI.{Event, Reducer, State, ViewModel}

  test "declarative chat view renders iodata lines" do
    view =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(Event.new(:user_message_added, "s1", %{text: "hello"}))
      |> Reducer.apply_event(Event.new(:assistant_message_added, "s1", %{text: "hi"}))
      |> ViewModel.from_state()

    lines = Chat.render_lines(view, 80, Theme.default())
    plain = Enum.map(lines, &Width.visible_text/1)

    assert ("  hello" <> String.duplicate(" ", 73)) in plain
    user_index = Enum.find_index(plain, &String.contains?(&1, "hello"))
    assistant_index = Enum.find_index(plain, &String.contains?(&1, "hi"))

    assert ("  hi" <> String.duplicate(" ", 76)) in plain
    assert Enum.any?(Enum.slice(plain, user_index..assistant_index), &(&1 == ""))
    refute "You: hello" in plain
    refute "Exy: hi" in plain
    assert Enum.any?(plain, &String.contains?(&1, "openai_codex:gpt-5.5"))
  end

  test "chat view renders subagent lifecycle blocks with attach command" do
    view =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(
        Event.new(:subagent_started, "s1", %{
          id: "sg-1",
          role: :scout,
          task: "inspect docs",
          child_session_id: "child-1"
        })
      )
      |> ViewModel.from_state()

    lines = Chat.render_lines(view, 80, Theme.default())
    plain = Enum.map(lines, &Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "subagent scout started"))
    assert Enum.any?(plain, &String.contains?(&1, "task: inspect docs"))
    assert Enum.any?(plain, &String.contains?(&1, "attach: exy a child-1"))
  end
end
