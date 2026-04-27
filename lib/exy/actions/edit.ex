defmodule Exy.Actions.Edit do
  @moduledoc false

  import JSONSpec

  @schema schema(
            %{
              required(:path) => String.t(),
              required(:edits) => [
                %{required(:oldText) => String.t(), required(:newText) => String.t()}
              ]
            },
            doc: [
              path: "Path to edit",
              edits:
                "Exact text replacements. Each oldText must uniquely match the original file; replacements are applied together."
            ]
          )

  use Jido.Action,
    name: "edit",
    description:
      "Edit a text file with exact replacements. Returns a line-numbered diff. Use for precise multi-location file edits.",
    schema: @schema

  @impl true
  def run(params, _context) do
    params = JSONSpec.atomize(@schema, params)

    Exy.Actions.ToolResult.run(fn -> Exy.Files.edit_file(params.path, params.edits) end)
  end
end
