defmodule Exy.Actions.AST do
  @moduledoc false

  import JSONSpec

  @schema schema(
            %{
              required(:action) => :search | :replace | :diff,
              optional(:path) => String.t(),
              optional(:pattern) => String.t(),
              optional(:replacement) => String.t(),
              optional(:old_file) => String.t(),
              optional(:new_file) => String.t(),
              optional(:old_source) => String.t(),
              optional(:new_source) => String.t(),
              optional(:inside) => String.t(),
              optional(:not_inside) => String.t(),
              optional(:dry_run) => boolean()
            },
            doc: [
              action: "search, replace, or diff",
              path: "File or directory path(s) for search/replace",
              pattern: "ExAST pattern",
              replacement: "ExAST replacement template",
              dry_run: "Preview replacements without writing"
            ]
          )

  use Jido.Action,
    name: "ast",
    description:
      "Structural Elixir search/replace/diff via ExAST. Use instead of grep for Elixir syntax.",
    schema: @schema

  @impl true
  def run(params, _context) do
    params = JSONSpec.atomize(@schema, params)

    Exy.Actions.ToolResult.run(fn ->
      case Exy.Code.AST.run(params) do
        {:ok, result} -> {:ok, Exy.ToolOutput.limit_value(result)}
        other -> other
      end
    end)
  end
end
