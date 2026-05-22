defmodule Vibe.Presentation.Tool.Read do
  @moduledoc "Semantic display builder for read tool results."
  alias Vibe.Files.ImageRef
  alias Vibe.Model.Content
  alias Vibe.Presentation.Tool.Display
  alias Vibe.Presentation.Tool.Util

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    result = Util.tool_output(tool)
    expanded? = Util.expanded?(tool)

    %Display{
      name: :read,
      status: Map.get(tool, :status),
      summary: Util.path_summary(tool, result),
      body: body(result),
      expanded?: expanded?,
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp body(%{error: error}), do: [{:error, to_string(error), []}]

  defp body(%{content_type: :image, image: %ImageRef{} = ref}) do
    [{:image_ref, ref, []}]
  end

  defp body(%{content_type: :image, parts: parts}) when is_list(parts) do
    Enum.map(parts, fn
      %Content.Text{text: text} -> {:text, text, []}
      %Content.Image{} = image -> {:image, image, []}
      %{type: "text", text: text} when is_binary(text) -> {:text, text, []}
      %{type: "image"} = image -> {:image, image, []}
      part -> {:inspect, inspect(part, pretty: true), []}
    end)
  end

  defp body(%{content: content} = result) when is_binary(content) do
    kind = if Util.markdown?(result), do: :markdown, else: :source

    opts = [
      language: Map.get(result, :language),
      read_limit_truncated?: Util.read_limit_truncated?(result),
      truncation: :head
    ]

    [{kind, content, opts}]
  end

  defp body(value), do: [{:text, format_value(value), []}]

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value, pretty: true, limit: 20)
end
