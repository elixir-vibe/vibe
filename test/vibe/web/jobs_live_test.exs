defmodule Vibe.Web.JobsLiveTest do
  use Vibe.WebCase, async: false

  setup do
    Vibe.Storage.ensure!()
    Vibe.Repo.delete_all(Vibe.Storage.Schema.SubagentJob)
    :ok
  end

  test "renders empty state" do
    conn = build_conn() |> get("/jobs")

    assert html_response(conn, 200) =~ "Jobs"
    assert html_response(conn, 200) =~ "No jobs yet"
  end
end
