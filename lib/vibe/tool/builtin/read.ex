defmodule Vibe.Tool.Builtin.Read do
  @moduledoc "Model-facing file and image read tool."
  import JSONSpec

  @schema schema(
            %{
              required(:path) => String.t(),
              optional(:limit_lines) => pos_integer(),
              optional(:limit_bytes) => pos_integer(),
              optional(:resize_images) => boolean(),
              optional(:max_width) => pos_integer(),
              optional(:max_height) => pos_integer(),
              optional(:max_bytes) => pos_integer()
            },
            doc: [
              path: "Path to read",
              limit_lines: "Maximum lines",
              limit_bytes: "Maximum bytes",
              resize_images: "Resize image files before returning them",
              max_width: "Maximum image width when resizing",
              max_height: "Maximum image height when resizing",
              max_bytes: "Maximum base64 image payload bytes when resizing"
            ]
          )

  @default_limit_lines 2_000

  use Jido.Action,
    name: "read",
    description:
      "Read a file from the project. Supports text files and images (png, jpg, gif, webp). Text returns content with line and truncation metadata; images return text and image parts.",
    schema: @schema

  @impl true
  def run(params, _context) do
    Vibe.Tool.AdapterResult.run(fn ->
      params = JSONSpec.atomize(@schema, params)

      Vibe.Files.read_file(params.path,
        limit_lines: Map.get(params, :limit_lines, @default_limit_lines),
        limit_bytes: Map.get(params, :limit_bytes, Vibe.Tool.Output.default_max_bytes()),
        resize?: Map.get(params, :resize_images, false),
        max_width: Map.get(params, :max_width, 2_000),
        max_height: Map.get(params, :max_height, 2_000),
        max_bytes: Map.get(params, :max_bytes, 4_500_000)
      )
    end)
  end
end
