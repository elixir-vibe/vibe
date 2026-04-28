defmodule Exy.Actions.Read do
  @moduledoc false

  import JSONSpec

  @schema schema(
            %{
              required(:path) => String.t(),
              optional(:limit_lines) => pos_integer(),
              optional(:limit_bytes) => pos_integer()
            },
            doc: [
              path: "Path to read",
              limit_lines: "Maximum lines",
              limit_bytes: "Maximum bytes"
            ]
          )

  @default_limit_lines 2_000

  use Jido.Action,
    name: "read",
    description:
      "Read a text file from the project. Returns content with line and truncation metadata.",
    schema: @schema

  @impl true
  def run(params, _context) do
    params = JSONSpec.atomize(@schema, params)

    Exy.Actions.ToolResult.run(fn ->
      Exy.Files.read_file(params.path,
        limit_lines: Map.get(params, :limit_lines, @default_limit_lines),
        limit_bytes: Map.get(params, :limit_bytes, Exy.ToolOutput.default_max_bytes())
      )
    end)
  end
end
