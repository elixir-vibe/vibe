defmodule Exy.ImageTest do
  use ExUnit.Case, async: true

  @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR", 0, 0, 0, 1, 0, 0, 0, 2, 8, 6,
         0, 0, 0, 0, 0, 0, 0>>

  test "detects supported image mime types" do
    assert Exy.Image.mime_type("a.png") == "image/png"
    assert Exy.Image.mime_type("a.JPG") == "image/jpeg"
    assert Exy.Image.supported?("a.webp")
    refute Exy.Image.supported?("a.txt")
  end

  test "reads image dimensions" do
    assert Exy.Image.Dimensions.detect(@png, "image/png") == {:ok, {1, 2}}
  end

  test "creates image content parts" do
    assert {:ok, image} =
             Exy.Image.from_base64(Base.encode64(@png), "image/png", filename: "tiny.png")

    assert image.width == 1
    assert image.height == 2

    assert [%Exy.Model.Content.Text{}, %Exy.Model.Content.Image{} = content] =
             Exy.Image.to_content_parts(image)

    assert content.mime_type == "image/png"
    assert content.filename == "tiny.png"
  end
end
