defmodule Exy.Web.StorageLiveTest do
  use Exy.WebCase, async: false

  setup do
    Exy.Session.Store.clear()
    Exy.Memory.clear(:user)
    Exy.Memory.clear(:global)
    :ok
  end

  test "renders storage search" do
    conn = build_conn() |> get("/storage")

    assert html_response(conn, 200) =~ "Storage"
    assert html_response(conn, 200) =~ "Search sessions and memory"
  end

  test "search route redirects to storage" do
    {:error, {:live_redirect, %{to: to}}} = live(build_conn(), "/search?q=hello")

    assert to == "/storage?q=hello"
  end
end
