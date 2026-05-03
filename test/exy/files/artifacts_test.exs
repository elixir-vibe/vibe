defmodule Exy.Files.ArtifactsTest do
  use ExUnit.Case, async: true

  alias Exy.Files.{Artifacts, ImageRef}
  alias Exy.Image

  test "keeps small images inline" do
    image = image(data: Base.encode64("small"))

    assert {:ok, ^image} = Artifacts.maybe_store_image(image, inline_image_bytes: 100)
  end

  test "stores large images as artifact refs without encoding data to JSON" do
    dir = Path.join(System.tmp_dir!(), "exy-artifact-test-#{System.unique_integer([:positive])}")
    image = image(data: Base.encode64("large-payload"))

    try do
      assert {:ok, %ImageRef{} = ref} =
               Artifacts.maybe_store_image(image,
                 inline_image_bytes: 4,
                 artifact_dir: dir
               )

      assert File.read!(ref.path) == "large-payload"
      assert ref.data == image.data

      encoded = Jason.encode!(ref)
      assert encoded =~ ref.path
      refute encoded =~ image.data
    after
      File.rm_rf(dir)
    end
  end

  defp image(opts) do
    %Image{
      data: Keyword.fetch!(opts, :data),
      mime_type: "image/png",
      filename: "sample.png",
      size_bytes: 5,
      width: 1,
      height: 1,
      original_width: 1,
      original_height: 1
    }
  end
end
