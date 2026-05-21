defmodule Vibe.ImageJSONTest do
  use ExUnit.Case, async: true

  test "image structs are not directly JSON encodable domain values" do
    image = %Vibe.Image{data: "abc", mime_type: "image/png", filename: "tiny.png"}

    assert_raise Protocol.UndefinedError, fn ->
      Jason.encode!(image)
    end
  end
end
