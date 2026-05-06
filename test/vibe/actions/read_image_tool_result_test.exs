defmodule Vibe.Actions.ReadImageToolResultTest do
  use ExUnit.Case, async: true

  alias ReqLLM.Message.ContentPart
  alias Vibe.Files.ReadResult
  alias Vibe.Model.Content

  test "image read results expose transient ReqLLM content parts for ReAct turns" do
    png =
      <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR", 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0,
        0, 0, 0, 0, 0, 0>>

    dir =
      Path.join(System.tmp_dir!(), "vibe-read-image-tool-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "tiny.png"), png)

    try do
      assert {:ok, result} = Vibe.Files.read_file("tiny.png", root: dir)

      assert [
               %ContentPart{type: :text},
               %ContentPart{type: :image_url} = image
             ] = result.__content_parts__

      assert image.url == "data:image/png;base64,#{Base.encode64(png)}"

      formatted = Jido.AI.Turn.format_tool_result_content({:ok, result})

      assert [
               %ContentPart{type: :text},
               %ContentPart{type: :text},
               %ContentPart{type: :image_url} = formatted_image
             ] = formatted

      assert formatted_image.url == image.url
    after
      File.rm_rf(dir)
    end
  end

  test "transient ReqLLM content parts are not duplicated in JSON storage" do
    result = %ReadResult{
      path: "tiny.png",
      content_type: :image,
      parts: [Content.text("Read image")],
      __content_parts__: [ContentPart.text("Read image")]
    }

    encoded = Jason.encode!(result)
    refute encoded =~ "__content_parts__"
  end
end
