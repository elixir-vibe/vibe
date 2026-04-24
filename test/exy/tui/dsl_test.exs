defmodule Exy.TUI.DSLTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{DSL, Node}

  test "constructs nodes outside the render dispatch module" do
    assert %Node{type: :vertical, children: [%Node{type: :text}]} =
             DSL.vertical([DSL.text("hello")])
  end
end
