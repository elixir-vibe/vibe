defmodule Vibe.Image.Resize.Backends.Sips do
  @moduledoc "macOS sips-backed image resize backend."

  @behaviour Vibe.Image.Resize.Backend

  alias Vibe.Image
  alias Vibe.Image.Resize.Backends.Command

  @supported_mime_types ["image/png", "image/jpeg"]

  @impl true
  def available?, do: Command.executable?("sips")

  @impl true
  def supports?(%Image{mime_type: mime_type}), do: mime_type in @supported_mime_types

  @impl true
  def resize(%Image{} = image, opts) do
    output_extension = extension(image.mime_type)
    max_dimension = max(opts[:max_width], opts[:max_height])

    Command.with_temp_files(image, output_extension, opts, fn input, output ->
      argv = [
        "sips",
        "--resampleHeightWidthMax",
        to_string(max_dimension),
        input,
        "--out",
        output
      ]

      with :ok <- Command.run(argv) do
        Command.image_from_output(image, output, image.mime_type)
      end
    end)
  end

  defp extension("image/jpeg"), do: ".jpg"
  defp extension(_mime_type), do: ".png"
end
