defmodule Exy.Web.SessionLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  @endpoint Exy.Web.Endpoint

  setup_all do
    Application.put_env(
      :exy,
      Exy.Web.Endpoint,
      Keyword.merge(Application.get_env(:exy, Exy.Web.Endpoint, []), server: false)
    )

    start_supervised!(Exy.Web.Endpoint)
    :ok
  end

  setup do
    Exy.Session.Store.clear()
    :ok
  end

  test "sessions page renders stored sessions" do
    Exy.Session.Store.ensure_session("web-list-session", ~U[2026-01-01 00:00:00Z],
      cwd: "/tmp/web"
    )

    conn = build_conn() |> get("/")

    assert html_response(conn, 200) =~ "Agent sessions"
    assert html_response(conn, 200) =~ "web-list-session"
  end

  test "session page starts and renders a session" do
    conn = build_conn() |> get("/sessions/web-live-session")

    assert html_response(conn, 200) =~ "web-live-session"
    assert html_response(conn, 200) =~ "Ask Exy"
  end

  test "search page renders" do
    conn = build_conn() |> get("/search")

    assert html_response(conn, 200) =~ "Search"
    assert html_response(conn, 200) =~ "Search sessions"
  end

  test "runtime page renders" do
    conn = build_conn() |> get("/runtime")

    assert html_response(conn, 200) =~ "Runtime"
    assert html_response(conn, 200) =~ "Top processes"
  end
end
