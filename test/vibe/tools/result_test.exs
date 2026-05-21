defmodule Vibe.Tools.ResultTest do
  use ExUnit.Case, async: true

  test "core tool results stay idiomatic" do
    assert {:ok, :value} = Vibe.Tools.Result.run(fn -> {:ok, :value} end)
    assert {:error, "boom"} = Vibe.Tools.Result.run(fn -> {:error, "boom"} end)
  end

  test "tool adapter normalizes failures into serializable successful results" do
    assert {:ok, %{error: "boom"}} = Vibe.Tools.ToolResult.run(fn -> {:error, "boom"} end)
    assert {:ok, %{error: "boom"}} = Vibe.Tools.ToolResult.error("boom")
    assert Jason.encode!(%{ok: true, result: %{error: "boom"}})
  end

  test "tool adapter captures unexpected exceptions as serializable tool results" do
    assert {:ok, %{error: error}} = Vibe.Tools.ToolResult.run(fn -> raise "boom" end)
    assert error =~ "boom"
    assert Jason.encode!(%{ok: true, result: %{error: error}})
  end

  test "model-facing tools normalize invalid argument shapes into serializable tool results" do
    for tool <- [
          Vibe.Tools.AST,
          Vibe.Tools.Edit,
          Vibe.Tools.Eval,
          Vibe.Tools.LSP,
          Vibe.Tools.Read,
          Vibe.Tools.Write
        ] do
      assert {:ok, %{error: error}} = tool.run([], %{})
      assert is_binary(error)
      assert Jason.encode!(%{ok: true, result: %{error: error}})
    end
  end
end
