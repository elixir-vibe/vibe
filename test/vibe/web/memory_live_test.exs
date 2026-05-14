defmodule Vibe.Web.MemoryLiveTest do
  use Vibe.WebCase, async: false

  setup do
    Vibe.Memory.clear(:user)
    Vibe.Memory.clear(:global)
    :ok
  end

  test "renders user memory page and manages memory entries" do
    conn = get(authenticated_conn(), "/memory")
    html = html_response(conn, 200)

    assert html =~ "Memory"
    assert html =~ "Save memory"

    assert {:ok, entry} = Vibe.Memory.add(:user, "Prefer semantic web renderers.")
    assert [^entry] = Vibe.Memory.list(:user)

    assert :ok = Vibe.Memory.remove(:user, entry.id)
    assert [] = Vibe.Memory.list(:user)
  end
end
