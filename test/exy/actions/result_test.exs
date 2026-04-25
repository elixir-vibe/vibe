defmodule Exy.Actions.ResultTest do
  use ExUnit.Case, async: true

  test "core action results stay idiomatic" do
    assert {:ok, :value} = Exy.Actions.Result.run(fn -> {:ok, :value} end)
    assert {:error, "boom"} = Exy.Actions.Result.run(fn -> {:error, "boom"} end)
  end

  test "tool adapter normalizes failures into serializable successful results" do
    assert {:ok, %{error: "boom"}} = Exy.Actions.ToolResult.run(fn -> {:error, "boom"} end)
    assert {:ok, %{error: "boom"}} = Exy.Actions.ToolResult.error("boom")
    assert Jason.encode!(%{ok: true, result: %{error: "boom"}})
  end

  test "tool adapter captures unexpected exceptions as serializable tool results" do
    assert {:ok, %{error: error}} = Exy.Actions.ToolResult.run(fn -> raise "boom" end)
    assert error =~ "boom"
    assert Jason.encode!(%{ok: true, result: %{error: error}})
  end
end
