defmodule Vibe.Web.AuthTest do
  use Vibe.WebCase

  test "rejects unauthenticated requests" do
    conn = Phoenix.ConnTest.build_conn() |> get("/")
    assert conn.status == 401
  end

  test "accepts valid token param and sets session" do
    token = Vibe.Web.Auth.token()
    conn = Phoenix.ConnTest.build_conn() |> get("/?token=#{token}")
    assert conn.status == 302
    assert Plug.Conn.get_resp_header(conn, "location") == ["/"]
  end

  test "rejects invalid token param" do
    conn = Phoenix.ConnTest.build_conn() |> get("/?token=wrong")
    assert conn.status == 401
  end

  test "authenticated session passes through" do
    conn = authenticated_conn() |> get("/")
    assert conn.status == 200
  end

  test "token is persistent across calls" do
    assert Vibe.Web.Auth.token() == Vibe.Web.Auth.token()
  end

  test "authenticated_url includes token" do
    url = Vibe.Web.Auth.authenticated_url()
    assert url =~ "token="
    assert url =~ Vibe.Web.Auth.token()
  end
end
