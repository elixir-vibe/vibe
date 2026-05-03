defmodule Exy.Image.Resize.Backends.Vips do
  @moduledoc "Image resize backend powered by libvips' `vips` CLI."
  @behaviour Exy.Image.Resize.Backend

  alias Exy.Image
  alias Exy.Image.Resize.Backends.Command

  @supported_mime_types ~w(image/jpeg image/png image/webp)

  @impl true
  def available?, do: Command.executable?("vips")

  @impl true
  def supports?(%Image{mime_type: mime_type}), do: mime_type in @supported_mime_types

  @impl true
  def resize(%Image{} = image, opts) do
    output_extension = output_extension(image)
    max_edge = max(Keyword.fetch!(opts, :max_width), Keyword.fetch!(opts, :max_height))

    Command.with_temp_files(image, output_extension, opts, fn input, output ->
      with :ok <-
             Command.run(
               [
                 "vips",
                 "thumbnail",
                 input,
                 output,
                 Integer.to_string(max_edge),
                 "--height",
                 Integer.to_string(Keyword.fetch!(opts, :max_height)),
                 "--size",
                 "down"
               ],
               opts
             ) do
        Command.image_from_output(image, output, image.mime_type)
      end
    end)
  end

  defp output_extension(%Image{mime_type: "image/jpeg"}), do: ".jpg"
  defp output_extension(%Image{mime_type: "image/png"}), do: ".png"
  defp output_extension(%Image{mime_type: "image/webp"}), do: ".webp"
end
