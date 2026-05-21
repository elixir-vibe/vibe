defmodule Vibe.Storage.Representation.EvalSnapshotTest do
  use ExUnit.Case, async: true

  alias Vibe.Storage.Representation.EvalSnapshot

  test "round-trips eval snapshots" do
    binding = [x: 2]
    env = __ENV__

    encoded = EvalSnapshot.encode(binding, env)

    assert {:ok, %{binding: ^binding, env: %Macro.Env{module: __MODULE__}}} =
             EvalSnapshot.decode(encoded)
  end

  test "decodes legacy base64 snapshot values" do
    binding = [answer: 42]
    encoded = binding |> EvalSnapshot.encode(__ENV__) |> Base.encode64()

    assert {:ok, %{binding: ^binding, env: %Macro.Env{module: __MODULE__}}} =
             EvalSnapshot.decode(encoded)
  end

  test "extracts snapshot entries from json lines" do
    {:ok, entry} = EvalSnapshot.entry("session-1", [value: :ok], __ENV__)
    line = Jason.encode!(entry)

    assert %{binding: [value: :ok], env: %Macro.Env{module: __MODULE__}} =
             EvalSnapshot.decode_line(line, :missing)
  end
end
