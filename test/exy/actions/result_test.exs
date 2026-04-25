defmodule Exy.Actions.ResultTest do
  use ExUnit.Case, async: true

  test "normalizes tool errors into serializable successful results" do
    assert {:ok, %{error: "boom"}} = Exy.Actions.Result.run(fn -> {:error, "boom"} end)
    assert {:ok, %{error: "boom"}} = Exy.Actions.Result.error("boom")
    assert Jason.encode!(%{ok: true, result: %{error: "boom"}})
  end

  test "captures unexpected exceptions as serializable tool results" do
    assert {:ok, %{error: error}} = Exy.Actions.Result.run(fn -> raise "boom" end)
    assert error =~ "boom"
    assert Jason.encode!(%{ok: true, result: %{error: error}})
  end
end
