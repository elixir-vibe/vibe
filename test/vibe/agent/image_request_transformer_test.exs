defmodule Vibe.Agent.ImageRequestTransformerTest do
  use ExUnit.Case, async: true

  alias ReqLLM.Message.ContentPart
  alias Vibe.Agent.ImageRequestTransformer
  alias Vibe.Model.Content

  test "injects image tool output as follow-up user content" do
    image = ContentPart.image_url("data:image/png;base64,AQID")

    request = %{
      messages: [
        %{role: :user, content: "read tiny.png"},
        %{
          role: :tool,
          tool_call_id: "call-1",
          name: "read",
          content: [ContentPart.text("ok"), image]
        }
      ],
      llm_opts: [],
      tools: []
    }

    assert {:ok, %{messages: messages}} =
             ImageRequestTransformer.transform_request(request, nil, nil, %{})

    assert [_, tool_message, follow_up] = messages
    assert tool_message == Enum.at(request.messages, 1)
    assert follow_up.role == :user
    assert [text, ^image] = follow_up.content
    assert text.type == :text
    assert text.text =~ "previous tool result included image content"
  end

  test "injects semantic prompt images into the latest user message" do
    image =
      Content.image(
        data: Base.encode64(<<1, 2, 3>>),
        mime_type: "image/png",
        filename: "tiny.png",
        width: 1,
        height: 1
      )

    request = %{messages: [%{role: :user, content: "describe this"}], llm_opts: [], tools: []}

    assert {:ok, %{messages: [%{content: [text, image_part]}]}} =
             ImageRequestTransformer.transform_request(request, nil, nil, %{
               semantic_prompt_content: [Content.text("describe this"), image]
             })

    assert text == ContentPart.text("describe this")
    assert image_part.type == :image
    assert image_part.filename == "tiny.png"
  end

  test "read image tool output reaches OpenAI Responses as input_image" do
    fixture = Path.expand("../../fixtures/images/two-by-two.png", __DIR__)

    assert {:ok, result} = Vibe.Files.read_file(fixture, root: "/")

    request = %{
      messages: [
        %{role: :user, content: "read #{fixture}"},
        %{
          role: :tool,
          tool_call_id: "call-1",
          name: "read",
          content: result.__content_parts__
        }
      ],
      llm_opts: [],
      tools: []
    }

    assert {:ok, %{messages: messages}} =
             ImageRequestTransformer.transform_request(request, nil, nil, %{})

    body = openai_responses_body(messages)

    assert Enum.any?(body["input"], fn
             %{"role" => "user", "content" => content} ->
               Enum.any?(content, fn
                 %{"type" => "input_image", "image_url" => "data:image/png;base64," <> _data} ->
                   true

                 _part ->
                   false
               end)

             _item ->
               false
           end)
  end

  test "injected follow-up reaches OpenAI Responses as input_image" do
    image = ContentPart.image_url("data:image/png;base64,AQID")

    request = %{
      messages: [
        %{role: :user, content: "read tiny.png"},
        %{
          role: :tool,
          tool_call_id: "call-1",
          name: "read",
          content: [ContentPart.text("ok"), image]
        }
      ],
      llm_opts: [],
      tools: []
    }

    assert {:ok, %{messages: messages}} =
             ImageRequestTransformer.transform_request(request, nil, nil, %{})

    body = openai_responses_body(messages)

    assert Enum.any?(body["input"], fn
             %{"role" => "user", "content" => content} ->
               Enum.any?(content, &(&1 == %{"type" => "input_image", "image_url" => image.url}))

             _item ->
               false
           end)
  end

  defp openai_responses_body(messages) do
    context = ReqLLM.Context.normalize!(messages)

    ReqLLM.Providers.OpenAI.ResponsesAPI.build_request_body(
      context,
      "gpt-4.1",
      [provider_options: [store: false]],
      nil
    )
  end

  test "leaves requests without image tool outputs unchanged" do
    request = %{
      messages: [
        %{role: :user, content: "hello"},
        %{role: :tool, tool_call_id: "call-1", name: "eval", content: [ContentPart.text("2")]}
      ],
      llm_opts: [],
      tools: []
    }

    assert {:ok, %{messages: messages}} =
             ImageRequestTransformer.transform_request(request, nil, nil, %{})

    assert messages == request.messages
  end
end
