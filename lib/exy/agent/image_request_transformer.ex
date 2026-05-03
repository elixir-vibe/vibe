defmodule Exy.Agent.ImageRequestTransformer do
  @moduledoc "Injects image tool outputs as multimodal follow-up user content."

  @behaviour Jido.AI.Reasoning.ReAct.RequestTransformer

  alias ReqLLM.Message.ContentPart

  @impl true
  def transform_request(%{messages: messages} = _request, _state, _config, _runtime_context)
      when is_list(messages) do
    {:ok, %{messages: Enum.flat_map(messages, &message_with_image_follow_up/1)}}
  end

  def transform_request(_request, _state, _config, _runtime_context), do: {:ok, %{}}

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
