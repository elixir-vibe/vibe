defmodule Exy.Image.ResizeBackendIntegrationTest do
  use ExUnit.Case, async: false

  alias Exy.Image
  alias Exy.Image.Resize.Backends.{ImageMagick, Sips}

  @tag :integration
  test "ImageMagick backend resizes PNG images when magick is available" do
    if ImageMagick.available?() do
      assert {:ok, resized} =
               ImageMagick.resize(sample_image(), max_width: 1, max_height: 1, quality: 80)

      assert %Image{mime_type: "image/png", width: 1, height: 1, was_resized?: true} = resized
    else
      :ok
    end
  end

  @tag :integration
  test "sips backend resizes PNG images when sips is available" do
    if Sips.available?() do
      assert {:ok, resized} =
               Sips.resize(sample_image(), max_width: 1, max_height: 1, quality: 80)

      assert %Image{mime_type: "image/png", width: 1, height: 1, was_resized?: true} = resized
    else
      :ok
    end
  end

  defp sample_image do
    content = File.read!(Path.expand("../../fixtures/images/two-by-two.png", __DIR__))
    {width, height} = Image.dimensions(content, "image/png")

    %Image{
      data: Base.encode64(content),
      mime_type: "image/png",
      filename: "two-by-two.png",
      size_bytes: byte_size(content),
      width: width,
      height: height,
      original_width: width,
      original_height: height,
      was_resized?: false
    }
  end
end
