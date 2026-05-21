defmodule Vibe.Tool.ResultTest do
  use ExUnit.Case, async: true

  test "core tool results stay idiomatic" do
    assert {:ok, :value} = Vibe.Tool.Result.run(fn -> {:ok, :value} end)
    assert {:error, "boom"} = Vibe.Tool.Result.run(fn -> {:error, "boom"} end)
  end

  test "tool adapter normalizes failures into serializable successful results" do
    assert {:ok, %{error: "boom"}} = Vibe.Tool.AdapterResult.run(fn -> {:error, "boom"} end)
    assert {:ok, %{error: "boom"}} = Vibe.Tool.AdapterResult.error("boom")
    assert Jason.encode!(%{ok: true, result: %{error: "boom"}})
  end

  test "tool adapter captures unexpected exceptions as serializable tool results" do
    assert {:ok, %{error: error}} = Vibe.Tool.AdapterResult.run(fn -> raise "boom" end)
    assert error =~ "boom"
    assert Jason.encode!(%{ok: true, result: %{error: error}})
  end

  test "model-facing tools normalize invalid argument shapes into serializable tool results" do
    for tool <- [
          Vibe.Tool.Builtin.AST,
          Vibe.Tool.Builtin.Edit,
          Vibe.Tool.Builtin.Eval,
          Vibe.Tool.Builtin.LSP,
          Vibe.Tool.Builtin.Read,
          Vibe.Tool.Builtin.Write
        ] do
      assert {:ok, %{error: error}} = tool.run([], %{})
      assert is_binary(error)
      assert Jason.encode!(%{ok: true, result: %{error: error}})
    end
  end
end
