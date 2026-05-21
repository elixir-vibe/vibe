defmodule Vibe.Model.ContentTest do
  use ExUnit.Case, async: true

  alias ReqLLM.Message.ContentPart
  alias Vibe.Model.Content

  test "converts Vibe content structs to ReqLLM content parts" do
    image_data = Base.encode64(<<1, 2, 3>>)

    parts =
      Content.to_req_llm_parts([
        Content.text("Look at this"),
        Content.image(
          data: image_data,
          mime_type: "image/png",
          filename: "tiny.png",
          width: 1,
          height: 1
        )
      ])

    assert [text, image] = parts
    assert text == ContentPart.text("Look at this")
    assert image.type == :image
    assert image.data == <<1, 2, 3>>
    assert image.media_type == "image/png"
    assert image.filename == "tiny.png"
    assert image.metadata == %{filename: "tiny.png", width: 1, height: 1}
  end

  test "summarizes images without raw base64 data" do
    summary =
      Content.summarize([
        Content.text("Describe"),
        Content.image(
          data: Base.encode64("secret-bytes"),
          mime_type: "image/png",
          filename: "tiny.png",
          width: 1,
          height: 2
        )
      ])

    assert summary =~ "Describe"
    assert summary =~ "[Image tiny.png image/png 1x2]"
    refute summary =~ Base.encode64("secret-bytes")
  end

  test "OpenAI Responses encodes converted images as input_image" do
    message =
      [
        Content.text("Describe"),
        Content.image(
          data: Base.encode64(<<1, 2, 3>>),
          mime_type: "image/png",
          filename: "tiny.png"
        )
      ]
      |> Content.to_req_llm_parts()
      |> ReqLLM.Context.user()

    context = ReqLLM.Context.new([message])

    body =
      ReqLLM.Providers.OpenAI.ResponsesAPI.build_request_body(
        context,
        "gpt-4.1",
        [provider_options: [store: false]],
        nil
      )

    assert [%{"content" => content}] = body["input"]
    assert %{"type" => "input_text", "text" => "Describe"} in content

    assert Enum.any?(
             content,
             &match?(%{"type" => "input_image", "image_url" => "data:image/png;base64,AQID"}, &1)
           )
  end

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
