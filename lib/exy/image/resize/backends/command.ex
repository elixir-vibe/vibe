defmodule Exy.Image.Resize.Backends.Command do
  @moduledoc "Shared helpers for command-backed image resize backends."

  alias Exy.Command
  alias Exy.Image

  @spec executable?(String.t()) :: boolean()
  def executable?(name), do: is_binary(System.find_executable(name))

  @spec with_temp_files(Image.t(), String.t(), keyword(), (Path.t(), Path.t() ->
                                                             {:ok, Image.t()} | {:error, term()})) ::
          {:ok, Image.t()} | {:error, term()}
  def with_temp_files(%Image{} = image, output_extension, opts, fun) when is_function(fun, 2) do
    case Base.decode64(image.data) do
      {:ok, binary} ->
        root =
          Path.join(
            Keyword.get(opts, :tmp_dir, System.tmp_dir!()),
            "exy-image-resize-#{System.unique_integer([:positive])}"
          )

        input = Path.join(root, "input#{extension(image)}")
        output = Path.join(root, "output#{output_extension}")

        try do
          File.mkdir_p!(root)
          File.write!(input, binary)
          fun.(input, output)
        after
          File.rm_rf(root)
        end

      :error ->
        {:error, :invalid_base64_image_data}
    end
  end

  @spec run([String.t()], keyword()) :: :ok | {:error, term()}
  def run(argv, opts \\ []) do
    case Command.run(argv, Keyword.put_new(opts, :timeout, 30_000)) do
      %Exy.Command.Result{status: :ok} -> :ok
      %Exy.Command.Result{} = result -> {:error, {:command_failed, result.status, result.output}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec image_from_output(Image.t(), Path.t(), String.t()) :: {:ok, Image.t()} | {:error, term()}
  def image_from_output(%Image{} = original, output, mime_type) do
    with {:ok, binary} <- File.read(output),
         {:ok, stat} <- File.stat(output) do
      {width, height} = Image.dimensions(binary, mime_type)

      {:ok,
       %Image{
         original
         | data: Base.encode64(binary),
           mime_type: mime_type,
           size_bytes: stat.size,
           width: width,
           height: height,
           original_width: original.original_width || original.width,
           original_height: original.original_height || original.height,
           was_resized?: true
       }}
    end
  end

  defp extension(%Image{mime_type: "image/jpeg"}), do: ".jpg"
  defp extension(%Image{mime_type: "image/png"}), do: ".png"
  defp extension(%Image{mime_type: "image/gif"}), do: ".gif"
  defp extension(%Image{mime_type: "image/webp"}), do: ".webp"
  defp extension(%Image{}), do: ".img"
end
