defmodule Exy.Files.ReadResult do
  @moduledoc "Typed result returned by file reads."

  alias Exy.Model.Content
  alias ReqLLM.Message.ContentPart

  @enforce_keys [:path, :content_type]
  defstruct [
    :path,
    :content_type,
    :content,
    :language,
    :lines,
    :omitted_lines,
    :omitted_bytes,
    :mime_type,
    :size_bytes,
    :width,
    :height,
    parts: [],
    __content_parts__: []
  ]

  @type content_type :: :text | :image

  @type t :: %__MODULE__{
          path: String.t(),
          content_type: content_type(),
          content: String.t() | nil,
          language: String.t() | nil,
          lines: non_neg_integer() | nil,
          omitted_lines: non_neg_integer() | nil,
          omitted_bytes: non_neg_integer() | nil,
          mime_type: String.t() | nil,
          size_bytes: non_neg_integer() | nil,
          width: pos_integer() | nil,
          height: pos_integer() | nil,
          parts: [Content.t()],
          __content_parts__: [ContentPart.t()]
        }
end

defimpl Jason.Encoder, for: Exy.Files.ReadResult do
  def encode(result, opts) do
    result
    |> Map.from_struct()
    |> Map.delete(:__content_parts__)
    |> Exy.JSON.Encode.value()
    |> Jason.Encode.map(opts)
  end
end
