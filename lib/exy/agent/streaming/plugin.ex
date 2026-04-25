defmodule Exy.Agent.Streaming.Plugin do
  @moduledoc false

  use Jido.Plugin,
    name: "exy_streaming",
    state_key: :exy_streaming,
    actions: [],
    signal_patterns: ["ai.llm.delta"]

  @impl true
  def handle_signal(%{type: "ai.llm.delta", data: data}, %{agent: %{id: agent_id}}) do
    Exy.Agent.Streaming.dispatch(agent_id, data || %{})
    {:ok, :continue}
  end

  def handle_signal(_signal, _context), do: {:ok, :continue}
end
