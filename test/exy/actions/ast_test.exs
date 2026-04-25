defmodule Exy.Actions.ASTTest do
  use ExUnit.Case, async: true

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
