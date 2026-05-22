defmodule Vibe.Storage.JSONTest do
  use ExUnit.Case, async: true

  test "projects date scalars through explicit protocol impls" do
    value = %{date: ~D[2026-05-22], at: ~U[2026-05-22 12:00:00Z]}

    assert Vibe.Storage.JSON.value(value) == %{
             "date" => "2026-05-22",
             "at" => "2026-05-22T12:00:00Z"
           }
  end

  test "value helper rejects structs instead of projecting them" do
    assert_raise ArgumentError, ~r/no storage JSON projection for Date/, fn ->
      Vibe.Storage.JSON.Value.value(~D[2026-05-22])
    end
  end
end
