defmodule Exy.Agent.Streaming.Plugin do
  @moduledoc false

  use Jido.Plugin,
    name: "exy_streaming",
    state_key: :exy_streaming,
    actions: [],
    signal_patterns: ["ai.llm.delta", "ai.tool.started", "ai.tool.result"]

  alias Exy.UI.ToolEvent

  @impl true
  def handle_signal(%{type: "ai.llm.delta", data: data}, %{agent: %{id: agent_id}}) do
    Exy.Agent.Streaming.dispatch(agent_id, data || %{})
    {:ok, :continue}
  end

  def handle_signal(
        %{type: "ai.tool.started", data: %{call_id: call_id, tool_name: tool_name} = data},
        %{agent: %{id: agent_id}}
      ) do
    Exy.Agent.Streaming.dispatch_tool_started(
      agent_id,
      ToolEvent.started(id: call_id, name: tool_name, args: Map.get(data, :arguments))
    )

    {:ok, :continue}
  end

  def handle_signal(
        %{
          type: "ai.tool.result",
          data: %{call_id: call_id, tool_name: tool_name, result: result} = data
        },
        %{agent: %{id: agent_id}}
      ) do
    Exy.Agent.Streaming.dispatch_tool_finished(
      agent_id,
      ToolEvent.finished(
        id: call_id,
        name: tool_name,
        args: Map.get(data, :arguments),
        output: result
      )
    )

    {:ok, :continue}
  end

  def handle_signal(_signal, _context), do: {:ok, :continue}
end
