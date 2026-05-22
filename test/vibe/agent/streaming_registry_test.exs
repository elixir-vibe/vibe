defmodule Vibe.Agent.StreamingRegistryTest do
  use ExUnit.Case, async: true

  test "streaming ETS tables are owned by supervised streaming registry" do
    owner = Process.whereis(Vibe.Agent.Streaming)

    assert :ets.info(:vibe_agent_streaming_callbacks, :owner) == owner
    assert :ets.info(:vibe_agent_streaming_runtime_delta_calls, :owner) == owner
  end
end
