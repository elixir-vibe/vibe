defmodule Vibe.RemoteTest do
  use ExUnit.Case, async: true

  test "remote facade rejects unsupported transports" do
    assert {:error, {:unsupported_transport, :bogus}} = Vibe.Remote.connect(transport: :bogus)
  end
end
