defmodule Exy.UI.AutocompleteTest do
  use ExUnit.Case, async: true

  alias Exy.UI.Autocomplete

  test "filters items by label value or detail" do
    autocomplete =
      Autocomplete.filter(
        [
          %{value: "/sessions", label: "/sessions", detail: "Browse stored sessions"},
          %{value: "/compact", label: "/compact", detail: "Summarize context"}
        ],
        "sess"
      )

    assert [%{value: "/sessions"}] = autocomplete.items
  end

  test "moves selected item within bounds" do
    autocomplete = Autocomplete.new(items: ["one", "two"], selected: 0)

    assert Autocomplete.move(autocomplete, 1).selected == 1
    assert Autocomplete.move(autocomplete, 10).selected == 1
    assert Autocomplete.move(autocomplete, -10).selected == 0
  end
end
