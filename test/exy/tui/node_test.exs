defmodule Exy.TUI.NodeTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{Node, Theme, Width}

  test "renders iodata lines" do
    lines =
      Node.vertical([
        Node.text(["hello", " ", "world"], fg: :accent),
        Node.text("plain")
      ])
      |> Node.render(80, Theme.default())

    assert [styled, "plain"] = lines
    assert IO.iodata_to_binary(styled) =~ IO.ANSI.cyan()
    assert Width.visible_text(styled) == "hello world"
  end

  test "renders semantic message blocks" do
    line =
      %{role: :user, text: "hello"}
      |> Node.message()
      |> Node.render(80, Theme.default())
      |> hd()

    assert Width.visible_text(line) == "You: hello"
  end
end
