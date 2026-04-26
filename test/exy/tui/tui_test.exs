defmodule Exy.TUITest do
  use ExUnit.Case, async: true

  alias Exy.TUI

  alias Exy.TUI.Node

  test "constructs nodes outside the render dispatch module" do
    assert %Node{type: :vertical, children: [%Node{type: :text}]} =
             TUI.vertical([TUI.text("hello")])
  end
end
