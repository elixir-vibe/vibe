defmodule Vibe.Web.ArtifactControllerTest do
  use Vibe.WebCase, async: false

  alias Vibe.Files.Artifacts

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "vibe-web-artifacts-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:vibe, :session_dir)
    Application.put_env(:vibe, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :session_dir, previous),
        else: Application.delete_env(:vibe, :session_dir)

      File.rm_rf(session_dir)
    end)

    {:ok, session_dir: session_dir}
  end

  test "serves session artifact files" do
    dir = Path.join(Artifacts.session_artifact_dir("session-1"), "images")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "tiny.png"), "png")

    conn = authenticated_conn() |> get("/sessions/session-1/artifacts/images/tiny.png")

    assert conn.status == 200
    assert conn.resp_body == "png"
  end

  test "serves nested URL-encoded artifact paths" do
    dir = Path.join(Artifacts.session_artifact_dir("session-1"), "images/nested")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "space name.png"), "png")

    conn =
      authenticated_conn() |> get("/sessions/session-1/artifacts/images/nested/space%20name.png")

    assert conn.status == 200
    assert conn.resp_body == "png"
  end

  test "returns 404 for missing files" do
    conn = authenticated_conn() |> get("/sessions/session-1/artifacts/images/missing.png")

    assert conn.status == 404
  end

  test "rejects invalid session ids" do
    conn = authenticated_conn() |> get("/sessions/bad:session/artifacts/images/tiny.png")

    assert conn.status == 404
  end

  test "rejects path traversal" do
    conn = authenticated_conn() |> get("/sessions/session-1/artifacts/../secret.txt")

    assert conn.status == 404
  end
end
