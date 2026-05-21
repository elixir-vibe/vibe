defmodule Vibe.Model.Content do
  @moduledoc "Provider-neutral model content parts."

  alias ReqLLM.Message.ContentPart

  defmodule Text do
    @moduledoc "Text content part."
    defstruct [:text]

    @type t :: %__MODULE__{text: String.t()}
  end

  defmodule Image do
    @moduledoc "Image content part with inline base64 data."
    defstruct [:data, :mime_type, :filename, :width, :height]

    @type t :: %__MODULE__{
            data: String.t(),
            mime_type: String.t(),
            filename: String.t() | nil,
            width: pos_integer() | nil,
            height: pos_integer() | nil
          }
  end

  @type t :: Text.t() | Image.t()

  @spec to_req_llm_parts([t() | ContentPart.t()]) :: [ContentPart.t()]
  def to_req_llm_parts(parts) when is_list(parts), do: Enum.map(parts, &to_req_llm_part/1)

  @spec to_req_llm_tool_parts([t() | ContentPart.t()]) :: [ContentPart.t()]
  def to_req_llm_tool_parts(parts) when is_list(parts),
    do: Enum.map(parts, &to_req_llm_tool_part/1)

  @spec to_req_llm_part(t() | ContentPart.t()) :: ContentPart.t()
  def to_req_llm_part(%ContentPart{} = part), do: part
  def to_req_llm_part(%Text{text: text}), do: ContentPart.text(text)

  def to_req_llm_part(%Image{} = image) do
    metadata =
      %{
        filename: image.filename,
        width: image.width,
        height: image.height
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    image.data
    |> Base.decode64!()
    |> ContentPart.image(image.mime_type, metadata)
    |> Map.put(:filename, image.filename)
  end

  @spec to_req_llm_tool_part(t() | ContentPart.t()) :: ContentPart.t()
  def to_req_llm_tool_part(%ContentPart{} = part), do: part
  def to_req_llm_tool_part(%Text{} = text), do: to_req_llm_part(text)

  def to_req_llm_tool_part(%Image{} = image) do
    metadata =
      %{filename: image.filename, width: image.width, height: image.height}
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    image
    |> data_uri()
    |> ContentPart.image_url(metadata)
  end

  @spec summarize(t() | [t()] | String.t()) :: String.t()
  def summarize(text) when is_binary(text), do: text
  def summarize(parts) when is_list(parts), do: Enum.map_join(parts, "\n", &summarize/1)
  def summarize(%Text{text: text}), do: text
  def summarize(%ContentPart{type: :text, text: text}) when is_binary(text), do: text

  def summarize(%ContentPart{type: type} = part) when type in [:image, :image_url] do
    ["[Image", Map.get(part, :filename), Map.get(part, :media_type) || Map.get(part, :mime_type)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> Kernel.<>("]")
  end

  def summarize(%Image{} = image) do
    ["[Image", image.filename, image.mime_type, dimensions(image)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> Kernel.<>("]")
  end

  @spec text(String.t()) :: Text.t()
  def text(value) when is_binary(value), do: %Text{text: value}

  @spec image(keyword()) :: Image.t()
  def image(fields) when is_list(fields) do
    %Image{
      data: Keyword.fetch!(fields, :data),
      mime_type: Keyword.fetch!(fields, :mime_type),
      filename: Keyword.get(fields, :filename),
      width: Keyword.get(fields, :width),
      height: Keyword.get(fields, :height)
    }
  end

  defp data_uri(%Image{} = image), do: "data:#{image.mime_type};base64,#{image.data}"

  defp dimensions(%Image{width: width, height: height})
       when is_integer(width) and is_integer(height),
       do: "#{width}x#{height}"

  defp dimensions(_image), do: nil
end
