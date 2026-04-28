defmodule Exy.Code.ASTTest do
  use ExUnit.Case, async: true

  test "search finds Elixir structure" do
    assert {:ok, %{action: :search, result: matches}} =
             Exy.Code.AST.run(action: :search, path: "lib/", pattern: "def run(_, _) do _ end")

    assert is_list(matches)
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
