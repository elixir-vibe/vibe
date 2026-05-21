defmodule Vibe.Web.SessionStreamingTest do
  use Vibe.WebCase

  test "session page receives live events from attached session" do
    session_id = "web-stream-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    {:ok, view, _html} = live(authenticated_conn(), "/sessions/#{session_id}")
    html = render(view)
    assert html =~ session_id

    Vibe.Session.emit_transient_event(
      session,
      Vibe.Event.new(:user_message_added, session_id, %{text: "streaming test prompt"})
    )

    Process.sleep(50)
    html = render(view)
    assert html =~ "streaming test prompt"

    Vibe.Session.emit_transient_event(
      session,
      Vibe.Event.new(:assistant_message_added, session_id, %{
        text: "streaming response from agent"
      })
    )

    Process.sleep(50)
    html = render(view)
    assert html =~ "streaming response from agent"

    GenServer.stop(session)
  end
end
