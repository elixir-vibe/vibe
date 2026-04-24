defmodule Exy.ASTTest do
  use ExUnit.Case, async: true

  test "search finds Elixir structure" do
    assert {:ok, matches} =
             Exy.AST.run(action: :search, path: "lib/", pattern: "def run(_, _) do _ end")

    assert is_list(matches)
  end

  test "diff reports semantic edits" do
    assert {:ok, diff} =
             Exy.AST.run(%{
               action: :diff,
               old_source: "defmodule A do\n  def x, do: 1\nend\n",
               new_source: "defmodule A do\n  def x, do: 2\nend\n"
             })

    assert diff.edits != []
  end
end
