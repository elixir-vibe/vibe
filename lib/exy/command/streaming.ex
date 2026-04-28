defmodule Exy.Command.Streaming do
  @moduledoc false

  alias Exy.UI.{Event, ToolEvent}

  @process_key :exy_eval_command_stream_session_id
  @flush_ms 100

  @spec with_eval_session(String.t() | nil, (-> term())) :: term()
  def with_eval_session(session_id, fun) when is_function(fun, 0) do
    previous = Process.get(@process_key)
    put_session_id(session_id)

    try do
      fun.()
    after
      restore_session_id(previous)
    end
  end

  @spec callback_from_process() :: (binary() -> :ok) | nil
  def callback_from_process do
    case Process.get(@process_key) do
      session_id when is_binary(session_id) -> callback(session_id)
      _session_id -> nil
    end
  end

  defp callback(session_id) do
    fn data ->
      if should_flush?(session_id) do
        emit(session_id, data)
      end

      :ok
    end
  end

  defp should_flush?(session_id) do
    key = {:exy_eval_command_stream_last_flush, session_id}
    now = System.monotonic_time(:millisecond)
    previous = Process.get(key)

    if is_nil(previous) or now - previous >= @flush_ms do
      Process.put(key, now)
      true
    else
      false
    end
  end

  defp emit(session_id, output) do
    with {:ok, session} <- Exy.UI.Bus.server(session_id),
         {:ok, tool} <- running_eval_tool(session) do
      Exy.Session.emit_transient_event(
        session,
        Event.new(
          :tool_updated,
          session_id,
          ToolEvent.started(
            id: Map.fetch!(tool, :id),
            name: :eval,
            args: Map.get(tool, :args),
            output: output,
            output_format: :text
          )
        )
      )
    end

    :ok
  end

  defp running_eval_tool(session) do
    session
    |> Exy.Session.state()
    |> Map.get(:pending_tools, %{})
    |> Enum.reverse()
    |> Enum.find_value(fn {_id, tool} ->
      if Map.get(tool, :name) in [:eval, "eval"] and
           Map.get(tool, :status) in [:running, "running"] do
        {:ok, tool}
      end
    end)
    |> case do
      nil -> :error
      result -> result
    end
  end

  defp put_session_id(session_id) when is_binary(session_id),
    do: Process.put(@process_key, session_id)

  defp put_session_id(_session_id), do: Process.delete(@process_key)

  defp restore_session_id(nil), do: Process.delete(@process_key)
  defp restore_session_id(session_id), do: Process.put(@process_key, session_id)
end
