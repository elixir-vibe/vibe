defmodule Vibe.Agent.ImageRequestTransformer do
  @moduledoc "Injects image tool outputs as multimodal follow-up user content."

  @behaviour Jido.AI.Reasoning.ReAct.RequestTransformer

  alias ReqLLM.Message.ContentPart
  alias Vibe.Model.Content

  @impl true
  def transform_request(%{messages: messages} = _request, _state, _config, runtime_context)
      when is_list(messages) do
    messages =
      messages
      |> attach_semantic_prompt_images(runtime_context)
      |> Enum.flat_map(&message_with_image_follow_up/1)

    {:ok, %{messages: messages}}
  end

  def transform_request(_request, _state, _config, _runtime_context), do: {:ok, %{}}

  defp attach_semantic_prompt_images(messages, runtime_context) do
    images = semantic_prompt_images(runtime_context)

    if images == [] do
      messages
    else
      List.update_at(messages, -1, &append_images_to_user_message(&1, images))
    end
  end

  defp semantic_prompt_images(%{semantic_prompt_content: content}) when is_list(content) do
    content
    |> Content.to_req_llm_parts()
    |> Enum.filter(&image_part?/1)
  end

  defp semantic_prompt_images(_runtime_context), do: []

  defp append_images_to_user_message(%{role: :user, content: text} = message, images)
       when is_binary(text) do
    %{message | content: [ContentPart.text(text) | images]}
  end

  defp append_images_to_user_message(%{role: :user, content: content} = message, images)
       when is_list(content) do
    %{message | content: content ++ images}
  end

  defp append_images_to_user_message(message, _images), do: message

  defp message_with_image_follow_up(message) do
    case tool_image_parts(message) do
      [] -> [message]
      images -> [message, image_follow_up(images)]
    end
  end

  defp image_follow_up(images) do
    %{
      role: :user,
      content: [
        ContentPart.text(
          "The previous tool result included image content. Use the attached image content directly when answering."
        )
        | images
      ]
    }
  end

  defp tool_image_parts(%{role: :tool, content: content}), do: image_parts(content)
  defp tool_image_parts(%{"role" => :tool, "content" => content}), do: image_parts(content)
  defp tool_image_parts(%{"role" => "tool", "content" => content}), do: image_parts(content)
  defp tool_image_parts(_message), do: []

  defp image_parts(content) when is_list(content) do
    Enum.filter(content, &image_part?/1)
  end

  defp image_parts(_content), do: []

  defp image_part?(%ContentPart{type: type}) when type in [:image, :image_url], do: true

  defp image_part?(%{type: type}) when type in [:image, :image_url, "image", "image_url"],
    do: true

  defp image_part?(%{"type" => type}) when type in [:image, :image_url, "image", "image_url"],
    do: true

  defp image_part?(_part), do: false
end
