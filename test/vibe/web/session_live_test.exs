defmodule Vibe.Web.SessionLiveTest do
  use Vibe.WebCase, async: false

  alias Vibe.Tool.Event, as: ToolEvent
  alias Vibe.Event

  setup do
    Vibe.Session.Store.clear()
    :ok
  end

  test "starts and renders a session" do
    conn = authenticated_conn() |> get("/sessions/web-live-session")

    assert html_response(conn, 200) =~ "web-live-session"
    assert html_response(conn, 200) =~ "Ask Vibe"
  end

  test "renders user attachment badge" do
    session_id = "web-user-attachment-session"

    Vibe.Session.Store.append_ui_events([
      {1, Event.new(:user_message_added, session_id, %{text: "describe", image_count: 1})}
    ])

    conn = authenticated_conn() |> get("/sessions/#{session_id}")
    html = html_response(conn, 200)

    assert html =~ "describe"
    assert html =~ "1 image attached"
  end

  test "renders tool calls as structured widgets" do
    session_id = "web-tool-session"

    Vibe.Session.Store.append_ui_events([
      {1,
       Event.new(
         :tool_started,
         session_id,
         Vibe.Event.Tool.started(
           ToolEvent.started(id: "tool-start", name: :eval, args: %{code: "1 + 1"})
         )
       )},
      {2,
       Event.new(
         :tool_finished,
         session_id,
         Vibe.Event.Tool.finished(
           ToolEvent.finished(
             id: "tool-start",
             name: :eval,
             args: %{code: "1 + 1"},
             output: %{output: "2", output_format: :inspect}
           )
         )
       )}
    ])

    conn = authenticated_conn() |> get("/sessions/#{session_id}")
    html = html_response(conn, 200)

    assert html =~ "Eval"
    refute html =~ "INSPECT"
    assert html =~ "2"
  end

  test "tolerates tool renderers with no output lines" do
    session_id = "web-empty-render-tool-session"

    Vibe.Session.Store.append_ui_events([
      {1,
       Event.new(
         :tool_started,
         session_id,
         Vibe.Event.Tool.started(
           ToolEvent.started(id: "tool-empty", name: :lsp, args: %{action: :hover})
         )
       )},
      {2,
       Event.new(
         :tool_finished,
         session_id,
         Vibe.Event.Tool.finished(
           ToolEvent.finished(id: "tool-empty", name: :lsp, args: %{action: :hover}, output: nil)
         )
       )}
    ])

    conn = authenticated_conn() |> get("/sessions/#{session_id}")
    html = html_response(conn, 200)

    assert html =~ "Lsp"
    assert html =~ "No tool output."
  end
end
