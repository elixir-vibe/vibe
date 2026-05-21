defmodule Vibe.Tool.Builtin.LSP do
  @moduledoc "Model-facing LSP interaction tool."
  import JSONSpec

  @schema schema(
            %{
              required(:action) =>
                :diagnostics
                | :definition
                | :references
                | :hover
                | :symbols
                | :workspace_symbols
                | :code_actions,
              optional(:cwd) => String.t(),
              optional(:file) => String.t(),
              optional(:line) => pos_integer(),
              optional(:column) => pos_integer(),
              optional(:query) => String.t(),
              optional(:wait_ms) => non_neg_integer()
            },
            doc: [
              action: "Expert LSP action",
              cwd: "Project root",
              file: "File path",
              line: "1-based line",
              column: "1-based column",
              query: "Workspace symbol query"
            ]
          )

  use Jido.Action,
    name: "lsp",
    description:
      "Ask Expert LSP for diagnostics, definitions, references, hover, symbols, and code actions.",
    schema: @schema

  @impl true
  def run(params, _context) do
    Vibe.Tool.AdapterResult.run(fn ->
      params = JSONSpec.atomize(@schema, params)

      case Vibe.Code.LSP.run(params) do
        {:ok, result} -> {:ok, %{result: Vibe.Tool.Output.limit_value(result)}}
        other -> other
      end
    end)
  end
end
