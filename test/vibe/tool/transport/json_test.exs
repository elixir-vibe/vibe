defmodule Vibe.Tool.Transport.JSONTest do
  use ExUnit.Case, async: true

  test "normalizes non-UTF8 binaries for JSON encoding" do
    assert %{type: "binary", data: data} = Vibe.Tool.Transport.JSON.value(<<0x89, 0xFF, 0x00>>)
    assert Base.decode64!(data) == <<0x89, 0xFF, 0x00>>
    assert Jason.encode!(%{payload: Vibe.Tool.Transport.JSON.value(<<0x89, 0xFF, 0x00>>)})
  end

  test "projects date scalars through explicit protocol impls" do
    value = %{date: ~D[2026-05-22], at: ~U[2026-05-22 12:00:00Z]}

    assert Vibe.Tool.Transport.JSON.value(value) == %{
             "date" => "2026-05-22",
             "at" => "2026-05-22T12:00:00Z"
           }
  end

  test "value helper rejects structs instead of projecting them" do
    assert_raise ArgumentError, ~r/no tool transport JSON projection for Date/, fn ->
      Vibe.Tool.Transport.JSON.Value.value(~D[2026-05-22])
    end
  end
end
