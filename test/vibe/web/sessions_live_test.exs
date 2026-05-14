defmodule Vibe.Web.SessionsLiveTest do
  use Vibe.WebCase, async: false

  setup do
    Vibe.Session.Store.clear()
    :ok
  end

  test "renders stored sessions" do
    Vibe.Session.Store.append_ui_event(
      Vibe.UI.Event.new(:user_message_added, "web-list-session", %{text: "hello web"}),
      1
    )

    conn = authenticated_conn() |> get("/")

    assert html_response(conn, 200) =~ "Agent sessions"
    assert html_response(conn, 200) =~ "web-list-session"
  end
end
