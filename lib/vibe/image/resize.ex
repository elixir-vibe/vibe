defmodule Vibe.Image.Resize do
  @moduledoc "Resize images through pluggable supervised command backends."

  alias Vibe.Image.Resize.Backends.{ImageMagick, Sips, Vips}

  @default_max_width 2_000
  @default_max_height 2_000
  @default_max_bytes 4_500_000
  @default_quality 80
  @default_backends [ImageMagick, Sips, Vips]

  @type backend :: module()

  @spec backends() :: [backend()]
  def backends, do: Application.get_env(:vibe, :image_resize_backends, @default_backends)

  @spec resize(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def resize(%{} = image, opts \\ []) do
    opts = normalize_opts(opts)

    if within_limits?(image, opts) do
      {:ok, image}
    else
      resize_with_backend(image, opts, Keyword.get(opts, :backends, backends()))
    end
  end

  @spec resize!(map(), keyword()) :: map()
  def resize!(%{} = image, opts \\ []) do
    case resize(image, opts) do
      {:ok, resized} -> resized
      {:error, reason} -> raise ArgumentError, "could not resize image: #{inspect(reason)}"
    end
  end

  @spec needs_resize?(map(), keyword()) :: boolean()
  def needs_resize?(%{} = image, opts \\ []),
    do: not within_limits?(image, normalize_opts(opts))

  defp resize_with_backend(_image, _opts, []), do: {:error, :no_available_image_resize_backend}

  defp resize_with_backend(image, opts, [backend | rest]) do
    cond do
      not Code.ensure_loaded?(backend) ->
        resize_with_backend(image, opts, rest)

      not backend.available?() ->
        resize_with_backend(image, opts, rest)

      not backend.supports?(image) ->
        resize_with_backend(image, opts, rest)

      true ->
        case backend.resize(image, opts) do
          {:ok, resized} -> {:ok, resized}
          {:error, _reason} -> resize_with_backend(image, opts, rest)
        end
    end
  end

  defp normalize_opts(opts) do
    opts
    |> Keyword.put_new(:max_width, @default_max_width)
    |> Keyword.put_new(:max_height, @default_max_height)
    |> Keyword.put_new(:max_bytes, @default_max_bytes)
    |> Keyword.put_new(:quality, @default_quality)
    |> Keyword.put_new_lazy(:tmp_dir, &System.tmp_dir!/0)
  end

  defp within_limits?(%{} = image, opts) do
    not too_wide?(image, opts) and not too_tall?(image, opts) and not too_large?(image, opts)
  end

  defp too_wide?(%{width: width}, opts) when is_integer(width), do: width > opts[:max_width]
  defp too_wide?(_image, _opts), do: false

  defp too_tall?(%{height: height}, opts) when is_integer(height), do: height > opts[:max_height]
  defp too_tall?(_image, _opts), do: false

  defp too_large?(%{size_bytes: size_bytes}, opts) when is_integer(size_bytes),
    do: encoded_size(size_bytes) > opts[:max_bytes]

  defp too_large?(%{data: data}, opts) when is_binary(data),
    do: byte_size(data) > opts[:max_bytes]

  defp too_large?(_image, _opts), do: false

  defp encoded_size(bytes), do: div(bytes + 2, 3) * 4
end
