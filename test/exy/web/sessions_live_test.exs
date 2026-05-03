defmodule Exy.Web.SessionsLiveTest do
  use Exy.WebCase, async: false

  setup do
    Exy.Session.Store.clear()
    :ok
  end

  test "renders stored sessions" do
    Exy.Session.Store.ensure_session("web-list-session", ~U[2026-01-01 00:00:00Z],
      cwd: "/tmp/web"
    )

    conn = build_conn() |> get("/")

    assert html_response(conn, 200) =~ "Agent sessions"
    assert html_response(conn, 200) =~ "web-list-session"
  end
end
