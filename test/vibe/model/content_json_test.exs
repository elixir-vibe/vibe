defmodule Vibe.Model.ContentJSONTest do
  use ExUnit.Case, async: true

  alias Vibe.Model.Content

  test "content JSON projection stays explicit" do
    content = Content.image(data: "abc", mime_type: "image/png", filename: "tiny.png")

    assert Vibe.JSON.Encode.value(content) == %{
             type: "image",
             data: "abc",
             mime_type: "image/png",
             filename: "tiny.png",
             width: nil,
             height: nil
           }
  end

  test "content structs are not directly JSON encodable domain values" do
    assert_raise Protocol.UndefinedError, fn ->
      Jason.encode!(Content.text("hello"))
    end
  end
end
