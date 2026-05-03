defmodule Exy.Web.StorageLiveTest do
  use Exy.WebCase, async: false

  setup do
    Exy.Session.Store.clear()
    Exy.Memory.clear(:user)
    Exy.Memory.clear(:global)
    :ok
  end

  test "renders storage search and artifact summary" do
    Exy.Session.Store.append_trajectory(:user_message, %{prompt: "hello"},
      session_id: "with-artifacts"
    )

    dir = Exy.Files.Artifacts.session_artifact_dir("with-artifacts")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "image.png"), "12345")

    conn = build_conn() |> get("/storage")
    html = html_response(conn, 200)

    assert html =~ "Storage"
    assert html =~ "Search sessions and memory"
    assert html =~ "Artifacts"
    assert html =~ "1 / 5 B"
  end

  test "search route redirects to storage" do
    {:error, {:live_redirect, %{to: to}}} = live(build_conn(), "/search?q=hello")

    assert to == "/storage?q=hello"
  end
end
