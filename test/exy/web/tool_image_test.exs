defmodule Exy.Web.ToolImageTest do
  use Exy.WebCase, async: false

  alias Exy.Files.{Artifacts, ImageRef}
  alias Exy.Tool.Display

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "exy-web-tool-image-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :session_dir, previous),
        else: Application.delete_env(:exy, :session_dir)

      File.rm_rf(session_dir)
    end)

    :ok
  end

  test "tool image refs render artifact URLs" do
    dir = Path.join(Artifacts.session_artifact_dir("session-1"), "images")
    File.mkdir_p!(dir)
    path = Path.join(dir, "tiny.png")
    File.write!(path, "png")

    tool = %{
      name: :read,
      status: :ok,
      output: %{
        content_type: :image,
        image: %ImageRef{
          path: path,
          mime_type: "image/png",
          filename: "tiny.png",
          width: 1,
          height: 1
        }
      }
    }

    assert %Display{body: [{:image_ref, ref, []}]} = Display.from_tool(tool)
    assert Artifacts.public_path(ref) == "/sessions/session-1/artifacts/images/tiny.png"
  end
end
