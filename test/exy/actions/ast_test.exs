defmodule Exy.Actions.ASTTest do
  use ExUnit.Case, async: true

  test "successful list results are wrapped in a map for action runtime validation" do
    dir = Path.join(System.tmp_dir!(), "exy-ast-action-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "sample.ex")
    File.write!(path, "defmodule Sample do\n  def add(left, right), do: left - right\nend\n")

    assert {:ok, %Exy.Code.AST.Result{result: [{^path, 1}], diff: [%{diff: diff}]}} =
             Exy.Actions.AST.run(
               %{
                 action: :replace,
                 path: path,
                 pattern: "left - right",
                 replacement: "left + right"
               },
               %{}
             )

    assert diff =~ "-  def add(left, right), do: left - right"
    assert diff =~ "+  def add(left, right), do: left + right"
    assert Jason.encode!(%{result: [{path, 1}]})

    File.rm_rf!(dir)
  end

  test "large errors are context-limited" do
    assert {:ok, %{error: output}} =
             Exy.Actions.AST.run(
               %{action: :diff, old_source: "", new_source: String.duplicate("x", 80_000)},
               %{}
             )

    assert byte_size(output) > Exy.ToolOutput.default_max_bytes()
    assert output =~ "tool output truncated"
  end
end
