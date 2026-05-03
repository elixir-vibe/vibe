defmodule Exy.Web.RuntimeLiveTest do
  use Exy.WebCase, async: false

  test "renders" do
    conn = build_conn() |> get("/runtime")

    assert html_response(conn, 200) =~ "Runtime"
    assert html_response(conn, 200) =~ "Top processes"
  end
end
