defmodule Vibe.Actions.Edit do
  @moduledoc "Model-facing file edit tool."
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

    Vibe.Actions.ToolResult.run(fn -> Vibe.Files.edit_file(params.path, params.edits) end)
  end
end
