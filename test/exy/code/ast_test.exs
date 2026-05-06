defmodule Exy.Code.ASTTest do
  use ExUnit.Case, async: true

  test "search finds Elixir structure" do
    assert {:ok, %{action: :search, result: matches}} =
             Exy.Code.AST.run(action: :search, path: "lib/", pattern: "def run(_, _) do _ end")

    assert is_list(matches)
  end

  test "search_many finds multiple named patterns in one traversal" do
    assert {:ok, %{action: :search_many, result: matches}} =
             Exy.Code.AST.run(%{
               action: :search_many,
               path: "lib/exy/code/ast.ex",
               allow_broad: true,
               patterns: %{
                 private_defs: "defp _ do ... end",
                 ast_calls: "ExAST.search(_, _, _)"
               }
             })

    assert Enum.any?(matches, &(&1.pattern == :private_defs))
    assert Enum.any?(matches, &(&1.pattern == :ast_calls))
  end

  test "public search_many helper returns matches" do
    matches =
      Exy.Code.AST.search_many(
        "lib/exy/code/ast.ex",
        %{ast_calls: "ExAST.search_many(_, _, _)"},
        allow_broad: true
      )

    assert Enum.any?(matches, &(&1.pattern == :ast_calls))
  end

  test "diff reports semantic edits" do
    assert {:ok, diff} =
             Exy.Code.AST.run(%{
               action: :diff,
               old_source: "defmodule A do\n  def x, do: 1\nend\n",
               new_source: "defmodule A do\n  def x, do: 2\nend\n"
             })

    assert diff.result.edits != []
  end
end
