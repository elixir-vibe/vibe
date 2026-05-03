defmodule Exy.Agent.ImageRequestTransformerTest do
  use ExUnit.Case, async: true

  alias Exy.Agent.ImageRequestTransformer
  alias ReqLLM.Message.ContentPart

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

    context = ReqLLM.Context.normalize!(messages)

    body =
      ReqLLM.Providers.OpenAI.ResponsesAPI.build_request_body(
        context,
        "gpt-4.1",
        [provider_options: [store: false]],
        nil
      )

    assert Enum.any?(body["input"], fn
             %{"role" => "user", "content" => content} ->
               Enum.any?(content, &(&1 == %{"type" => "input_image", "image_url" => image.url}))

             _item ->
               false
           end)
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
