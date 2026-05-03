defmodule Exy.Model.ContentTest do
  use ExUnit.Case, async: true

  test "converts Exy content structs to ReqLLM content parts" do
    image_data = Base.encode64(<<1, 2, 3>>)

    parts =
      Exy.Model.Content.to_req_llm_parts([
        Exy.Model.Content.text("Look at this"),
        Exy.Model.Content.image(
          data: image_data,
          mime_type: "image/png",
          filename: "tiny.png",
          width: 1,
          height: 1
        )
      ])

    assert [text, image] = parts
    assert text == ReqLLM.Message.ContentPart.text("Look at this")
    assert image.type == :image
    assert image.data == <<1, 2, 3>>
    assert image.media_type == "image/png"
    assert image.filename == "tiny.png"
    assert image.metadata == %{filename: "tiny.png", width: 1, height: 1}
  end

  test "summarizes images without raw base64 data" do
    summary =
      Exy.Model.Content.summarize([
        Exy.Model.Content.text("Describe"),
        Exy.Model.Content.image(
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
        Exy.Model.Content.text("Describe"),
        Exy.Model.Content.image(
          data: Base.encode64(<<1, 2, 3>>),
          mime_type: "image/png",
          filename: "tiny.png"
        )
      ]
      |> Exy.Model.Content.to_req_llm_parts()
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
end
