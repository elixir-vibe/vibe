defmodule Vibe.JSON.EncodeTest do
  use ExUnit.Case, async: true

  test "normalizes non-UTF8 binaries for JSON encoding" do
    assert %{type: "binary", data: data} = Vibe.JSON.Encode.value(<<0x89, 0xFF, 0x00>>)
    assert Base.decode64!(data) == <<0x89, 0xFF, 0x00>>
    assert Jason.encode!(%{payload: Vibe.JSON.Encode.value(<<0x89, 0xFF, 0x00>>)})
  end
end
