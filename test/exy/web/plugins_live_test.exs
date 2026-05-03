defmodule Exy.Web.PluginsLiveTest do
  use Exy.WebCase, async: false

  test "renders plugin capabilities" do
    conn = build_conn() |> get("/plugins")
    html = html_response(conn, 200)

    assert html =~ "Plugins"
    assert html =~ "Discovered"
    assert html =~ "APIs"
    assert html =~ "/plugins/"
  end
end
