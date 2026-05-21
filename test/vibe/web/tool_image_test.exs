defmodule Vibe.Web.ToolImageTest do
  use Vibe.WebCase, async: false

  import Phoenix.Component

  alias Vibe.Files.{Artifacts, ImageRef}
  alias Vibe.Tool.Presentation, as: Display

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "vibe-web-tool-image-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:vibe, :session_dir)
    Application.put_env(:vibe, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :session_dir, previous),
        else: Application.delete_env(:vibe, :session_dir)

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

    assigns = %{block: {:image_ref, ref, []}}

    html =
      rendered_to_string(~H"""
      <Vibe.Web.Components.Tool.tool_body_block block={@block} />
      """)

    assert html =~ ~s(href="/sessions/session-1/artifacts/images/tiny.png")
    assert html =~ "Open original"
  end
end
