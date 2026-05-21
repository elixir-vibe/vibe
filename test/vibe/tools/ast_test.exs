defmodule Vibe.Tools.ASTTest do
  use ExUnit.Case, async: true

  alias Vibe.Code.AST.Result

  @large_source_chars 80_000

  test "successful list results are wrapped in a map for tool runtime validation" do
    dir = Path.join(System.tmp_dir!(), "vibe-ast-action-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "sample.ex")
    File.write!(path, "defmodule Sample do\n  def add(left, right), do: left - right\nend\n")

    assert {:ok, %Result{result: [{^path, 1}], diff: [%{diff: diff}]}} =
             Vibe.Tools.AST.run(
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
             Vibe.Tools.AST.run(
               %{
                 action: :diff,
                 old_source: "",
                 new_source: String.duplicate("x", @large_source_chars)
               },
               %{}
             )

    assert byte_size(output) > Vibe.ToolOutput.default_max_bytes()
    assert output =~ "tool output truncated"
  end
end
