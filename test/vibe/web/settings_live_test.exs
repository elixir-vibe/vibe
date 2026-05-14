defmodule Vibe.Web.SettingsLiveTest do
  use Vibe.WebCase, async: false

  test "renders model and auth settings" do
    conn = authenticated_conn() |> get("/settings")
    html = html_response(conn, 200)

    assert html =~ "Settings"
    assert html =~ "Default model"
    assert html =~ "Auth"
    assert html =~ "Roles"
    assert html =~ "Prompts"
    assert html =~ "System prompt"
  end
end
