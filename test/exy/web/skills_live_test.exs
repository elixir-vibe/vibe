defmodule Exy.Web.SkillsLiveTest do
  use Exy.WebCase, async: false

  test "renders skills" do
    conn = build_conn() |> get("/skills")
    html = html_response(conn, 200)

    assert html =~ "Skills"
    assert html =~ "Skill paths"
    assert html =~ "Markdown"
    assert html =~ "Executable"
    refute html =~ "Preview"
  end
end
