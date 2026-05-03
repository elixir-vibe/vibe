defmodule Exy.Eval.ImageTest do
  use ExUnit.Case, async: true

  test "eval exposes Image alias and returns typed image display parts" do
    session_id = "eval-image-#{System.unique_integer([:positive])}"

    data =
      Base.encode64(
        <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR", 0, 0, 0, 1, 0, 0, 0, 1, 8, 6,
          0, 0, 0, 0, 0, 0, 0>>
      )

    code = "Image.from_base64!(\"#{data}\", \"image/png\", filename: \"tiny.png\")"

    assert {:ok, result} = Exy.Eval.once(code, session_id: session_id)
    assert result.value_type == Exy.Image
    assert [%Exy.Model.Content.Text{}, %Exy.Model.Content.Image{} = image] = result.parts
    assert image.filename == "tiny.png"
    assert image.mime_type == "image/png"
  end
end
