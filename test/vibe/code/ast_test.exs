defmodule Vibe.Code.ASTTest do
  use ExUnit.Case, async: true

  test "search finds Elixir structure" do
    path =
      Path.join(System.tmp_dir!(), "vibe-ast-search-#{System.unique_integer([:positive])}.ex")

    File.write!(path, "defmodule Fixture do\n  def run(_, _) do\n    :ok\n  end\nend\n")

    try do
      assert {:ok, %{action: :search, result: matches}} =
               Vibe.Code.AST.run(action: :search, path: path, pattern: "def run(_, _) do _ end")

      assert [_match] = matches
    after
      File.rm(path)
    end
  end

  test "search_many finds multiple named patterns in one traversal" do
    assert {:ok, %{action: :search_many, result: matches}} =
             Vibe.Code.AST.run(%{
               action: :search_many,
               path: "lib/vibe/code/ast.ex",
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
      Vibe.Code.AST.search_many(
        "lib/vibe/code/ast.ex",
        %{ast_calls: "ExAST.search_many(_, _, _)"},
        allow_broad: true
      )

    assert Enum.any?(matches, &(&1.pattern == :ast_calls))
  end

  test "diff reports semantic edits" do
    assert {:ok, diff} =
             Vibe.Code.AST.run(%{
               action: :diff,
               old_source: "defmodule A do\n  def x, do: 1\nend\n",
               new_source: "defmodule A do\n  def x, do: 2\nend\n"
             })

    assert diff.result.edits != []
  end
end
