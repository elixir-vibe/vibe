defmodule Exy.Agent.Streaming.Plugin do
  @moduledoc """
  Jido plugin that translates runtime and tool signals into Exy stream callbacks.

  ReAct runtime delta events are preferred over derived `ai.llm.delta` signals
  because runtime events include sequence metadata. Tool lifecycle signals are
  converted into `Exy.UI.ToolEvent` values for the TUI/session reducer.
  """

  use Jido.Plugin,
    name: "exy_streaming",
    state_key: :exy_streaming,
    actions: [],
    signal_patterns: [
      "ai.react.worker.event",
      "ai.react.runtime_event",
      "ai.llm.delta",
      "ai.tool.params",
      "ai.tool.started",
      "ai.tool.result"
    ]

  alias Exy.UI.ToolEvent

  require Exy.Debug

  @impl true
  def handle_signal(
        %{type: type, data: %{event: event}},
        %{agent: %{id: agent_id}}
      )
      when type in ["ai.react.worker.event", "ai.react.runtime_event"] and is_map(event) do
    case event_kind(event) do
      :llm_delta ->
        data = event_data(event)
        call_id = event_field(event, :llm_call_id)

        Exy.Debug.run do
          Exy.Agent.Streaming.Trace.record(:react_runtime_delta, %{
            agent_id: agent_id,
            call_id: call_id,
            runtime_seq: event_field(event, :seq),
            run_id: event_field(event, :run_id),
            request_id: event_field(event, :request_id),
            iteration: event_field(event, :iteration),
            chunk_type: event_field(data, :chunk_type, :content),
            delta: event_field(data, :delta, "")
          })
        end

        Exy.Agent.Streaming.dispatch_runtime_delta(
          agent_id,
          call_id,
          %{
            call_id: call_id,
            runtime_seq: event_field(event, :seq),
            chunk_type: event_field(data, :chunk_type, :content),
            delta: event_field(data, :delta, "")
          }
        )

      :llm_completed ->
        Exy.Agent.Streaming.finish_runtime_call(agent_id, event_field(event, :llm_call_id))

      _kind ->
        :ok
    end

    {:ok, :continue}
  end

  def handle_signal(%{type: "ai.llm.delta", data: data}, %{agent: %{id: agent_id}}) do
    Exy.Agent.Streaming.dispatch(agent_id, data || %{})
    {:ok, :continue}
  end

  def handle_signal(
        %{type: "ai.tool.params", data: %{call_id: call_id, tool_name: tool_name} = data},
        %{agent: %{id: agent_id}}
      ) do
    Exy.Agent.Streaming.dispatch_tool_preparing(
      agent_id,
      ToolEvent.preparing(id: call_id, name: tool_name, args: Map.get(data, :arguments))
    )

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

  defp event_kind(event) do
    case event_field(event, :kind) do
      kind when is_atom(kind) -> kind
      kind when is_binary(kind) -> String.to_existing_atom(kind)
      _kind -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp event_data(event), do: event_field(event, :data, %{}) || %{}

  defp event_field(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end
