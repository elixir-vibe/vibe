defmodule Vibe.Web.StorageLiveTest do
  use Vibe.WebCase, async: false

  setup do
    Vibe.Session.Store.clear()
    Vibe.Memory.clear(:user)
    Vibe.Memory.clear(:global)
    :ok
  end

  test "renders storage search and artifact summary" do
    Vibe.Session.Store.append_trajectory(:user_message, %{prompt: "hello"},
      session_id: "with-artifacts"
    )

    dir = Vibe.Files.Artifacts.session_artifact_dir("with-artifacts")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "image.png"), "12345")

    conn = authenticated_conn() |> get("/storage")
    html = html_response(conn, 200)

    assert html =~ "Storage"
    assert html =~ "Search sessions and memory"
    assert html =~ "Artifacts"
    assert html =~ "1 / 5 B"
  end

  test "escapes search snippets while preserving semantic highlights" do
    :ok =
      Vibe.Event.new(
        :user_message_added,
        "web-storage-xss",
        %{text: ~S|<script>alert("x")</script> needle|},
        at: ~U[2026-01-01 00:00:00Z]
      )
      |> Vibe.Session.Store.append_event(1)

    conn = authenticated_conn() |> get("/storage?q=needle")
    html = html_response(conn, 200)

    refute html =~ ~S|<script>alert("x")</script>|
    assert html =~ "&lt;script&gt;alert("
    assert html =~ "<mark"
    assert html =~ "needle"
  end

  test "search route redirects to storage" do
    {:error, {:live_redirect, %{to: to}}} = live(authenticated_conn(), "/search?q=hello")

    assert to == "/storage?q=hello"
  end
end
