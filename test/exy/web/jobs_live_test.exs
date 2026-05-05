defmodule Exy.Web.JobsLiveTest do
  use Exy.WebCase, async: false

  setup do
    Exy.Storage.ensure!()
    Exy.Repo.delete_all(Exy.Storage.Schema.SubagentJob)
    :ok
  end

  test "renders empty state" do
    conn = build_conn() |> get("/jobs")

    assert html_response(conn, 200) =~ "Jobs"
    assert html_response(conn, 200) =~ "No jobs yet"
  end
end
