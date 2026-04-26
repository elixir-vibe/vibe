defmodule Exy.TUI.NodeTest do
  use ExUnit.Case, async: true

  alias Exy.TUI

  alias Exy.TUI.{Theme, Widget, Width}

  test "renders iodata lines" do
    lines =
      TUI.vertical([
        TUI.text(["hello", " ", "world"], fg: :accent),
        TUI.text("plain")
      ])
      |> Widget.render(80, Theme.default())

    assert [styled, "plain"] = lines
    assert IO.iodata_to_binary(styled) =~ "\e[38;2;178;148;187m"
    assert Width.visible_text(styled) == "hello world"
  end

  test "renders semantic message blocks" do
    lines =
      %{role: :user, text: "hello"}
      |> TUI.message()
      |> Widget.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert lines == [
             String.duplicate(" ", 80),
             "  hello" <> String.duplicate(" ", 73),
             String.duplicate(" ", 80)
           ]
  end
end
