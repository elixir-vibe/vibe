defmodule Vibe.Image.Resize.Backends.ImageMagick do
  @moduledoc "ImageMagick-backed image resize backend."

  @behaviour Vibe.Image.Resize.Backend

  alias Vibe.Image
  alias Vibe.Image.Resize.Backends.Command

  @impl true
  def available?, do: Command.executable?("magick")

  @impl true
  def supports?(%Image{}), do: true

  @impl true
  def resize(%Image{} = image, opts) do
    output_mime_type = output_mime_type(image)
    output_extension = extension(output_mime_type)
    geometry = "#{opts[:max_width]}x#{opts[:max_height]}>"

    Command.with_temp_files(image, output_extension, opts, fn input, output ->
      argv = [
        "magick",
        input,
        "-auto-orient",
        "-resize",
        geometry,
        "-quality",
        to_string(opts[:quality]),
        output
      ]

      with :ok <- Command.run(argv) do
        Command.image_from_output(image, output, output_mime_type)
      end
    end)
  end

  defp output_mime_type(%Image{mime_type: "image/gif"}), do: "image/png"
  defp output_mime_type(%Image{} = image), do: image.mime_type || "image/png"

  defp extension("image/jpeg"), do: ".jpg"
  defp extension("image/webp"), do: ".webp"
  defp extension(_mime_type), do: ".png"
end
