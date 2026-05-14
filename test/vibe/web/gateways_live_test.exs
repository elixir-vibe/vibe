defmodule Vibe.Web.GatewaysLiveTest do
  use Vibe.WebCase, async: false

  test "renders gateway dashboard" do
    conn = authenticated_conn() |> get("/gateways")

    html = html_response(conn, 200)
    assert html =~ "Gateways"
    assert html =~ "Gateway runtimes"
    assert html =~ "Recent gateway sessions"
  end
end
