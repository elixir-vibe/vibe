defmodule Vibe.Agent.Streaming.Plugin do
  @moduledoc """
  Jido plugin that translates runtime and tool signals into Vibe stream callbacks.

  ReAct runtime delta events are preferred over derived `ai.llm.delta` signals
  because runtime events include sequence metadata. Tool lifecycle signals are
  converted into `Vibe.UI.ToolEvent` values for the TUI/session reducer.
  """

  use Jido.Plugin,
    name: "vibe_streaming",
    state_key: :vibe_streaming,
    actions: [],
    signal_patterns: [
      "ai.react.worker.event",
      "ai.react.runtime_event",
      "ai.llm.delta",
      "ai.tool.params",
      "ai.tool.started",
      "ai.tool.result"
    ]

  alias ReqLLM.StreamChunk
  alias Vibe.UI.ToolEvent

  require Vibe.Debug

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

        Vibe.Debug.run do
          Vibe.Agent.Streaming.Trace.record(:react_runtime_delta, %{
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

        Vibe.Agent.Streaming.dispatch_runtime_delta(
          agent_id,
          call_id,
          stream_chunk(data, call_id: call_id, runtime_seq: event_field(event, :seq))
        )

      :llm_completed ->
        Vibe.Agent.Streaming.finish_runtime_call(agent_id, event_field(event, :llm_call_id))

      _kind ->
        :ok
    end

    {:ok, :continue}
  end

  def handle_signal(%{type: "ai.llm.delta", data: data}, %{agent: %{id: agent_id}}) do
    Vibe.Agent.Streaming.dispatch(agent_id, delta_data(data || %{}))
    {:ok, :continue}
  end

  def handle_signal(%{type: "ai.tool.params", data: data}, %{agent: %{id: agent_id}})
      when is_map(data) do
    Vibe.Agent.Streaming.dispatch_tool_preparing(
      agent_id,
      ToolEvent.preparing(
        id: tool_call_id(data),
        name: tool_name(data),
        args: tool_arguments(data)
      )
    )

    {:ok, :continue}
  end

  def handle_signal(%{type: "ai.tool.started", data: data}, %{agent: %{id: agent_id}})
      when is_map(data) do
    Vibe.Agent.Streaming.dispatch_tool_started(
      agent_id,
      ToolEvent.started(
        id: tool_call_id(data),
        name: tool_name(data),
        args: tool_arguments(data)
      )
    )

    {:ok, :continue}
  end

  def handle_signal(%{type: "ai.tool.result", data: data}, %{agent: %{id: agent_id}})
      when is_map(data) do
    Vibe.Agent.Streaming.dispatch_tool_finished(
      agent_id,
      ToolEvent.finished(
        id: tool_call_id(data),
        name: tool_name(data),
        args: tool_arguments(data),
        output: event_field(data, :result)
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

  defp delta_data(data) when is_map(data) do
    stream_chunk(data, call_id: event_field(data, :call_id))
  end

  defp stream_chunk(data, metadata) do
    type = event_field(data, :chunk_type, :content)
    text = event_field(data, :delta, "")

    metadata =
      metadata
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    case type do
      :thinking -> StreamChunk.thinking(text, metadata)
      "thinking" -> StreamChunk.thinking(text, metadata)
      _type -> StreamChunk.text(text, metadata)
    end
  end

  defp tool_call_id(data),
    do: event_field(data, :call_id) || event_field(data, :tool_call_id) || event_field(data, :id)

  defp tool_name(data), do: event_field(data, :tool_name) || event_field(data, :name)

  defp tool_arguments(data) do
    event_field(data, :arguments) || event_field(data, :args)
  end

  defp event_field(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end
