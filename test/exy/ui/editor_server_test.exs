defmodule Exy.UI.EditorServerTest do
  use ExUnit.Case, async: true

  alias Exy.UI.EditorServer

  test "wraps editor in gen_statem" do
    {:ok, pid} = EditorServer.start_link()

    assert [] = EditorServer.key(pid, {:insert, "hello"})
    assert [{:submit, "hello"}] = EditorServer.key(pid, :submit)
    assert EditorServer.state(pid).text == ""
  end

  test "inserts text programmatically" do
    {:ok, pid} = EditorServer.start_link(text: "describe")

    assert :ok = EditorServer.insert(pid, " @image.png")
    assert EditorServer.state(pid).text == "describe @image.png"
  end
end
