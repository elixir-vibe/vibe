defmodule Exy.Files.Artifacts do
  @moduledoc "Stores large tool artifacts outside inline session JSON payloads."

  alias Exy.Files.ImageRef
  alias Exy.Image
  alias Exy.Paths

  @default_inline_image_bytes 1_000_000

  @spec maybe_store_image(Image.t(), keyword()) ::
          {:ok, Image.t() | ImageRef.t()} | {:error, term()}
  def maybe_store_image(%Image{} = image, opts \\ []) do
    limit = Keyword.get(opts, :inline_image_bytes, default_inline_image_bytes())

    if byte_size(image.data) <= limit do
      {:ok, image}
    else
      store_image(image, opts)
    end
  end

  @spec store_image(Image.t(), keyword()) :: {:ok, ImageRef.t()} | {:error, term()}
  def store_image(%Image{} = image, opts \\ []) do
    case Base.decode64(image.data) do
      {:ok, binary} ->
        dir = image_dir(opts)
        path = Path.join(dir, artifact_filename(image))

        File.mkdir_p!(dir)
        File.write!(path, binary)

        {:ok,
         %ImageRef{
           path: path,
           mime_type: image.mime_type,
           filename: image.filename,
           size_bytes: image.size_bytes,
           width: image.width,
           height: image.height,
           data: image.data
         }}

      :error ->
        {:error, :invalid_base64_image_data}
    end
  end

  @spec default_inline_image_bytes() :: pos_integer()
  def default_inline_image_bytes do
    Application.get_env(:exy, :inline_image_bytes, @default_inline_image_bytes)
  end

  defp image_dir(opts) do
    cond do
      dir = Keyword.get(opts, :artifact_dir) ->
        dir

      session_id = Keyword.get(opts, :session_id) ->
        Path.join([Paths.sessions_dir(), session_id, "artifacts", "images"])

      true ->
        Path.join([Paths.sessions_dir(), "artifacts", "images"])
    end
  end

  defp artifact_filename(%Image{} = image) do
    extension = extension(image.mime_type)
    basename = image.filename || "image#{extension}"

    digest =
      :crypto.hash(:sha256, image.data) |> Base.url_encode64(padding: false) |> binary_part(0, 16)

    root = basename |> Path.basename() |> Path.rootname() |> safe_name()
    "#{root}-#{digest}#{extension}"
  end

  defp safe_name(name) do
    name
    |> String.replace(~r/[^A-Za-z0-9._-]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "image"
      safe -> safe
    end
  end

  defp extension("image/jpeg"), do: ".jpg"
  defp extension("image/png"), do: ".png"
  defp extension("image/gif"), do: ".gif"
  defp extension("image/webp"), do: ".webp"
  defp extension(_mime_type), do: ".img"
end
