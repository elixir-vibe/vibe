defmodule Vibe.Web.Presentation.ToolImageComponentTest do
  use Vibe.WebCase, async: true

  import Phoenix.Component

  alias Vibe.Model.Content
  alias Vibe.Web.Presentation.Tool

  test "image captions include dimensions and byte size" do
    assigns = %{
      block:
        {:image,
         Content.image(
           data: Base.encode64("png"),
           mime_type: "image/png",
           filename: "tiny.png",
           width: 2,
           height: 2
         ), []}
    }

    html =
      rendered_to_string(~H"""
      <Tool.tool_body_block block={@block} />
      """)

    assert html =~ "tiny.png · image/png · 2×2"
    assert html =~ "4 B"
    assert html =~ ~s(loading="lazy")
  end
end
