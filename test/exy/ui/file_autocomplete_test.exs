defmodule Exy.UI.FileAutocompleteTest do
  use ExUnit.Case, async: true

  alias Exy.UI.FileAutocomplete

  setup do
    root =
      Path.join(System.tmp_dir!(), "exy-file-autocomplete-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, "screenshots"))
    File.write!(Path.join(root, "screenshots/one.png"), "png")
    File.write!(Path.join(root, "space name.png"), "png")

    on_exit(fn -> File.rm_rf(root) end)
    {:ok, root: root}
  end

  test "suggests attachment completions", %{root: root} do
    autocomplete = FileAutocomplete.autocomplete("describe @screenshots/o", root: root)

    assert autocomplete.title == "Attach file"
    assert [%{value: "@screenshots/one.png"}] = autocomplete.items
  end

  test "quotes attachment completions with spaces", %{root: root} do
    autocomplete = FileAutocomplete.autocomplete("describe @space", root: root)

    assert [%{value: ~s(@"space name.png")}] = autocomplete.items
  end

  test "does not trigger for email addresses" do
    assert FileAutocomplete.autocomplete("mail a@example", root: "/tmp") == nil
  end
end
