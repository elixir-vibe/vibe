defmodule Vibe.TUI.PickerPresenterTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.PickerPresenter
  alias Vibe.UI.Autocomplete
  alias Vibe.UI.Selector

  test "presents confirmation selectors as confirmation pickers" do
    selector = %Selector{kind: :model, overlay_kind: :confirmation, items: [], selected: 0}

    assert %{type: :confirmation, props: props} =
             PickerPresenter.from_snapshot(%{ui: %{selector: selector}})

    assert props.kind == :model
  end

  test "presents plain-map confirmation selectors as confirmation pickers" do
    selector = %{
      kind: :clear_session_confirmation,
      overlay_kind: :confirmation,
      title: "Clear session?",
      items: ["Yes", "No"],
      selected: 0
    }

    assert %{type: :confirmation, props: props} =
             PickerPresenter.from_snapshot(%{ui: %{selector: selector}})

    assert props.kind == :clear_session_confirmation
    assert props.items == ["Yes", "No"]
  end

  test "presents selectors as select lists" do
    selector = %Selector{kind: :model, items: [], selected: 0}

    assert %{type: :select_list, props: ^selector} =
             PickerPresenter.from_snapshot(%{ui: %{selector: selector}})
  end

  test "presents autocomplete state" do
    autocomplete = %Autocomplete{
      items: [%{value: "/model"}],
      selected: 0,
      query: "/m",
      replace_from: 0
    }

    assert %{type: :autocomplete, props: props} =
             PickerPresenter.from_snapshot(%{ui: %{}, autocomplete: autocomplete})

    assert props.query == "/m"
  end

  test "returns nil without picker state" do
    assert is_nil(PickerPresenter.from_snapshot(%{ui: %{}, autocomplete: nil}))
  end
end
