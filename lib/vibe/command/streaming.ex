defmodule Vibe.Command.Streaming do
  @moduledoc "Streaming output capture for long-running commands."
  alias Vibe.Tool.Event, as: ToolEvent
  alias Vibe.Event

  @flush_ms 100

  @spec with_eval_session(String.t() | nil, (-> term())) :: term()
  def with_eval_session(session_id, fun) when is_function(fun, 0) do
    Vibe.Session.Current.with_session(session_id, fun)
  end

  @spec current_session_id() :: String.t() | nil
  def current_session_id do
    Vibe.Session.Current.session_id()
  end

  @spec track(String.t() | nil, pid()) :: :ok
  def track(session_id, pid) when is_binary(session_id) and is_pid(pid) do
    Vibe.Command.Processes.track(session_id, pid)
  end

  def track(_session_id, _pid), do: :ok

  @spec untrack(String.t() | nil, pid()) :: :ok
  def untrack(session_id, pid) when is_binary(session_id) and is_pid(pid) do
    Vibe.Command.Processes.untrack(session_id, pid)
  end

  def untrack(_session_id, _pid), do: :ok

  @spec callback_from_process() :: (binary() -> :ok) | nil
  def callback_from_process do
    case current_session_id() do
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
    key = flush_key(session_id)
    now = System.monotonic_time(:millisecond)

    if flush_due?(Process.get(key), now) do
      Process.put(key, now)
      true
    else
      false
    end
  end

  defp flush_key(session_id), do: {:vibe_eval_command_stream_last_flush, session_id}
  defp flush_due?(nil, _now), do: true
  defp flush_due?(previous, now), do: now - previous >= @flush_ms

  defp emit(session_id, output) do
    with {:ok, session} <- Vibe.Event.Bus.server(session_id),
         {:ok, tool} <- running_eval_tool(session) do
      GenServer.call(
        session,
        {:emit_transient_event,
         Event.new(
           :tool_updated,
           session_id,
           Vibe.Event.Tool.updated(
             ToolEvent.started(
               id: Map.fetch!(tool, :id),
               name: :eval,
               args: Map.get(tool, :args),
               output: output,
               output_format: :text
             )
           )
         )}
      )
    end

    :ok
  end

  defp running_eval_tool(session) do
    session
    |> GenServer.call(:state)
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
end
