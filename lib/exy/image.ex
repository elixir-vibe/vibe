defmodule Exy.Image do
  @moduledoc "Image data helpers for model, eval, and renderer boundaries."

  @supported_mime_types %{
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".webp" => "image/webp"
  }

  defstruct [
    :data,
    :mime_type,
    :path,
    :filename,
    :size_bytes,
    :width,
    :height,
    :original_width,
    :original_height,
    was_resized?: false
  ]

  @type t :: %__MODULE__{
          data: String.t(),
          mime_type: String.t(),
          path: String.t() | nil,
          filename: String.t() | nil,
          size_bytes: non_neg_integer() | nil,
          width: pos_integer() | nil,
          height: pos_integer() | nil,
          original_width: pos_integer() | nil,
          original_height: pos_integer() | nil,
          was_resized?: boolean()
        }

  @spec supported_mime_types() :: [String.t()]
  def supported_mime_types, do: @supported_mime_types |> Map.values() |> Enum.uniq()

  @spec mime_type(String.t()) :: String.t() | nil
  def mime_type(path) when is_binary(path) do
    @supported_mime_types[String.downcase(Path.extname(path))]
  end

  @spec supported?(String.t()) :: boolean()
  def supported?(path), do: is_binary(mime_type(path))

  @spec from_file(String.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def from_file(path, opts \\ []) when is_binary(path) do
    with {:ok, absolute} <- resolve(path, opts),
         mime_type when is_binary(mime_type) <- mime_type(absolute),
         {:ok, stat} <- File.stat(absolute),
         {:ok, binary} <- File.read(absolute) do
      {width, height} = dimensions(binary, mime_type)

      {:ok,
       %__MODULE__{
         data: Base.encode64(binary),
         mime_type: mime_type,
         path: path,
         filename: Path.basename(path),
         size_bytes: stat.size,
         width: width,
         height: height,
         original_width: width,
         original_height: height,
         was_resized?: false
       }}
    else
      nil -> {:error, "unsupported image type: #{path}"}
      {:error, %File.Error{} = error} -> {:error, Exception.message(error)}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @spec from_base64(String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def from_base64(data, mime_type, opts \\ []) when is_binary(data) and is_binary(mime_type) do
    case Base.decode64(data) do
      {:ok, binary} ->
        {width, height} = dimensions(binary, mime_type)

        {:ok,
         %__MODULE__{
           data: data,
           mime_type: mime_type,
           path: Keyword.get(opts, :path),
           filename: Keyword.get(opts, :filename),
           size_bytes: byte_size(binary),
           width: width,
           height: height,
           original_width: width,
           original_height: height,
           was_resized?: false
         }}

      :error ->
        {:error, "invalid base64 image data"}
    end
  end

  @spec from_base64!(String.t(), String.t(), keyword()) :: t()
  def from_base64!(data, mime_type, opts \\ []) do
    case from_base64(data, mime_type, opts) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec dimensions(binary(), String.t()) :: {pos_integer() | nil, pos_integer() | nil}
  def dimensions(binary, mime_type) when is_binary(binary) and is_binary(mime_type) do
    case Exy.Image.Dimensions.detect(binary, mime_type) do
      {:ok, {width, height}} -> {width, height}
      :error -> {nil, nil}
    end
  end

  @spec data_uri(t()) :: String.t()
  def data_uri(%__MODULE__{} = image),
    do: "#{image.mime_type};base64,#{image.data}" |> then(&("data:" <> &1))

  @spec to_content_parts(t()) :: [map()]
  def to_content_parts(%__MODULE__{} = image) do
    note =
      ["Read image file [#{image.mime_type}]", dimension_text(image)]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n")

    [
      Exy.Model.Content.text(note),
      Exy.Model.Content.image(
        data: image.data,
        mime_type: image.mime_type,
        filename: image.filename,
        width: image.width,
        height: image.height
      )
    ]
  end

  defp dimension_text(%{width: width, height: height})
       when is_integer(width) and is_integer(height),
       do: "#{width}x#{height}"

  defp dimension_text(_image), do: nil

  defp resolve(path, opts) do
    case Keyword.fetch(opts, :absolute) do
      {:ok, absolute} -> {:ok, absolute}
      :error -> Exy.Workspace.resolve(path, opts)
    end
  end
end

defimpl Jason.Encoder, for: Exy.Image do
  def encode(image, opts) do
    Jason.Encode.map(
      %{
        data: image.data,
        mime_type: image.mime_type,
        path: image.path,
        filename: image.filename,
        size_bytes: image.size_bytes,
        width: image.width,
        height: image.height,
        original_width: image.original_width,
        original_height: image.original_height,
        was_resized?: image.was_resized?
      },
      opts
    )
  end
end
