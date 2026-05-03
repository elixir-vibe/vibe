defmodule Exy.Web.JobsLiveTest do
  use Exy.WebCase, async: false

  test "renders empty state" do
    conn = build_conn() |> get("/jobs")

    assert html_response(conn, 200) =~ "Jobs"
    assert html_response(conn, 200) =~ "No jobs yet"
  end
end
