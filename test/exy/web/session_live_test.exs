defmodule Exy.Web.SessionLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  alias Exy.UI.{Event, ToolEvent}

  @endpoint Exy.Web.Endpoint

  setup_all do
    Application.put_env(
      :exy,
      Exy.Web.Endpoint,
      Keyword.merge(Application.get_env(:exy, Exy.Web.Endpoint, []), server: false)
    )

    start_supervised!(Exy.Web.Endpoint)
    :ok
  end

  setup do
    Exy.Session.Store.clear()
    :ok
  end

  test "sessions page renders stored sessions" do
    Exy.Session.Store.ensure_session("web-list-session", ~U[2026-01-01 00:00:00Z],
      cwd: "/tmp/web"
    )

    conn = build_conn() |> get("/")

    assert html_response(conn, 200) =~ "Agent sessions"
    assert html_response(conn, 200) =~ "web-list-session"
  end

  test "session page starts and renders a session" do
    conn = build_conn() |> get("/sessions/web-live-session")

    assert html_response(conn, 200) =~ "web-live-session"
    assert html_response(conn, 200) =~ "Ask Exy"
  end

  test "search page renders" do
    conn = build_conn() |> get("/search")

    assert html_response(conn, 200) =~ "Search"
    assert html_response(conn, 200) =~ "Search sessions"
  end

  test "runtime page renders" do
    conn = build_conn() |> get("/runtime")

    assert html_response(conn, 200) =~ "Runtime"
    assert html_response(conn, 200) =~ "Top processes"
  end

  test "session page renders tool calls as structured widgets" do
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
    assert html =~ "1 + 1"
    assert html =~ "Inspect"
    assert html =~ "2"
  end

  test "session page hides stored TUI transcript artifacts when semantic events exist" do
    session_id = "web-stored-tool-transcript-session"

    Exy.Session.Store.append_ui_events([
      {1, Event.new(:user_message_added, session_id, %{text: "Real user prompt"})},
      {2, Event.new(:user_message_added, session_id, %{text: "◆ eval • File.cwd!()  ✓"})},
      {3, Event.new(:user_message_added, session_id, %{text: "\"/tmp\""})},
      {4,
       Event.new(
         :tool_started,
         session_id,
         ToolEvent.started(id: "tool-eval", name: :eval, args: %{code: "File.cwd!()"})
       )},
      {5,
       Event.new(
         :tool_finished,
         session_id,
         ToolEvent.finished(id: "tool-eval", name: :eval, output: "\"/tmp\"", status: :ok)
       )},
      {6, Event.new(:assistant_message_added, session_id, %{text: "Done."})}
    ])

    conn = build_conn() |> get("/sessions/#{session_id}")
    html = html_response(conn, 200)

    assert html =~ "Real user prompt"
    assert html =~ "Eval"
    assert html =~ "File.cwd!()"
    assert html =~ ~s(&quot;/tmp&quot;)
    refute html =~ "◆ eval"
  end

  test "session page tolerates tool renderers with no output lines" do
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
