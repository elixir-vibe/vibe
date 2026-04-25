defmodule Exy.TUI.NodeTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{DSL, Theme, Widget, Width}

  test "renders iodata lines" do
    lines =
      DSL.vertical([
        DSL.text(["hello", " ", "world"], fg: :accent),
        DSL.text("plain")
      ])
      |> Widget.render(80, Theme.default())

    assert [styled, "plain"] = lines
    assert IO.iodata_to_binary(styled) =~ IO.ANSI.color(3, 4, 4)
    assert Width.visible_text(styled) == "hello world"
  end

  test "renders semantic message blocks" do
    line =
      %{role: :user, text: "hello"}
      |> DSL.message()
      |> Widget.render(80, Theme.default())
      |> hd()

    assert Width.visible_text(line) == "You: hello"
  end
end
