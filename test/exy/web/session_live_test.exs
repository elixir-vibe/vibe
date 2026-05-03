defmodule Exy.Web.SessionLiveTest do
  use Exy.WebCase, async: false

  alias Exy.UI.{Event, ToolEvent}

  setup do
    Exy.Session.Store.clear()
    :ok
  end

  test "starts and renders a session" do
    conn = build_conn() |> get("/sessions/web-live-session")

    assert html_response(conn, 200) =~ "web-live-session"
    assert html_response(conn, 200) =~ "Ask Exy"
  end

  test "renders tool calls as structured widgets" do
    session_id = "web-tool-session"

    Exy.Session.Store.append_ui_events([
      {1,
       Event.new(
         :tool_started,
         session_id,
         ToolEvent.started(id: "tool-start", name: :eval, args: %{code: "1 + 1"})
       )},
      {2,
       Event.new(
         :tool_finished,
         session_id,
         ToolEvent.finished(
           id: "tool-start",
           name: :eval,
           args: %{code: "1 + 1"},
           output: %{output: "2", output_format: :inspect}
         )
       )}
    ])

    conn = build_conn() |> get("/sessions/#{session_id}")
    html = html_response(conn, 200)

    assert html =~ "Eval"
    refute html =~ "INSPECT"
    assert html =~ "2"
  end

  test "tolerates tool renderers with no output lines" do
    session_id = "web-empty-render-tool-session"

    Exy.Session.Store.append_ui_events([
      {1,
       Event.new(
         :tool_started,
         session_id,
         ToolEvent.started(id: "tool-empty", name: :lsp, args: %{action: :hover})
       )},
      {2,
       Event.new(
         :tool_finished,
         session_id,
         ToolEvent.finished(id: "tool-empty", name: :lsp, args: %{action: :hover}, output: nil)
       )}
    ])

    conn = build_conn() |> get("/sessions/#{session_id}")
    html = html_response(conn, 200)

    assert html =~ "Lsp"
    assert html =~ "No tool output."
  end
end
