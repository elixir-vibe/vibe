defmodule Vibe.Session.Current do
  @moduledoc false

  @process_key :vibe_eval_command_stream_session_id

  @spec with_session(String.t() | nil, (-> term())) :: term()
  def with_session(session_id, fun) when is_function(fun, 0) do
    previous = Process.get(@process_key)
    put_session_id(session_id)

    try do
      fun.()
    after
      restore_session_id(previous)
    end
  end

  @spec session_id() :: String.t() | nil
  def session_id do
    case Process.get(@process_key) do
      session_id when is_binary(session_id) -> session_id
      _session_id -> nil
    end
  end

  defp put_session_id(nil), do: Process.delete(@process_key)

  defp put_session_id(session_id) when is_binary(session_id),
    do: Process.put(@process_key, session_id)

  defp restore_session_id(nil), do: Process.delete(@process_key)
  defp restore_session_id(session_id), do: Process.put(@process_key, session_id)
end
