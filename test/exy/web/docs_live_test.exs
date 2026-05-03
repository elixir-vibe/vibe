defmodule Exy.Web.DocsLiveTest do
  use Exy.WebCase, async: false

  test "renders default docs topic" do
    conn = build_conn() |> get("/docs")

    assert html_response(conn, 200) =~ "Quickstart"
    assert html_response(conn, 200) =~ "Built-in Exy docs"
  end

  test "renders selected docs topic" do
    conn = build_conn() |> get("/docs/memory")

    assert html_response(conn, 200) =~ "Memory"
    assert html_response(conn, 200) =~ "Built-in Exy docs · memory"
  end
end
