defmodule Exy.Command.Streaming do
  @moduledoc false

  alias Exy.UI.{Event, ToolEvent}

  @process_key :exy_eval_command_stream_session_id
  @table __MODULE__
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

  @spec current_session_id() :: String.t() | nil
  def current_session_id do
    case Process.get(@process_key) do
      session_id when is_binary(session_id) -> session_id
      _session_id -> nil
    end
  end

  @spec track(String.t() | nil, pid()) :: :ok
  def track(session_id, pid) when is_binary(session_id) and is_pid(pid) do
    ensure_table()
    :ets.insert(@table, {{session_id, pid}, true})
    :ok
  end

  def track(_session_id, _pid), do: :ok

  @spec untrack(String.t() | nil, pid()) :: :ok
  def untrack(session_id, pid) when is_binary(session_id) and is_pid(pid) do
    ensure_table()
    :ets.delete(@table, {session_id, pid})
    :ok
  end

  def untrack(_session_id, _pid), do: :ok

  @spec cancel_session(String.t()) :: :ok
  def cancel_session(session_id) when is_binary(session_id) do
    ensure_table()

    @table
    |> :ets.match({{session_id, :"$1"}, :_})
    |> List.flatten()
    |> Enum.each(fn pid ->
      if is_pid(pid) and Process.alive?(pid), do: Exy.Command.cancel(pid)
      untrack(session_id, pid)
    end)

    :ok
  end

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

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true])

      _tid ->
        @table
    end
  rescue
    ArgumentError -> @table
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
