defmodule Vibe.TUI.InputControllerTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.InputController
  alias Vibe.UI.{Autocomplete, EditorServer, Selector, State}

  test "moves autocomplete selection" do
    {:ok, editor} = EditorServer.start_link()

    state = %{
      editor: editor,
      ui: self(),
      ui_snapshot: %State{},
      autocomplete: %Autocomplete{items: [%{value: "/model"}, %{value: "/help"}], selected: 0}
    }

    state = InputController.handle_key(:down, state)

    assert state.autocomplete.selected == 1
  end

  test "applies tab completion at replacement position" do
    {:ok, editor} = EditorServer.start_link()
    :ok = EditorServer.replace(editor, "say /mo")

    state = %{
      editor: editor,
      ui: self(),
      ui_snapshot: %State{},
      autocomplete: %Autocomplete{items: [%{value: "/model"}], selected: 0, replace_from: 4}
    }

    state = InputController.handle_key(:tab, state)

    assert state.autocomplete == nil
    assert EditorServer.state(editor).text == "say /model "
  end

  test "selector cancel closes selector locally" do
    {:ok, session} = Vibe.Session.start_link(persist?: false)
    {:ok, editor} = EditorServer.start_link()
    {:ok, snapshot, _cursor} = Vibe.Session.attach(session, self())

    selector = %Selector{kind: :model, items: [%{label: "a"}], selected: 0}
    snapshot = %{snapshot | selector: selector}

    state = %{editor: editor, ui: session, ui_snapshot: snapshot, autocomplete: nil}
    state = InputController.handle_key(:cancel, state)

    assert state.ui_snapshot.selector == nil
  end
end
