defmodule Vibe.Agent.Streaming.Registry do
  @moduledoc "ETS-backed callback and runtime-call registry for agent streaming."

  @callbacks_table :vibe_agent_streaming_callbacks
  @runtime_delta_table :vibe_agent_streaming_runtime_delta_calls

  @spec ensure_tables!() :: :ok
  def ensure_tables! do
    ensure_named_table(@callbacks_table)
    ensure_named_table(@runtime_delta_table)
    :ok
  end

  @spec put_callbacks(String.t(), map()) :: :ok
  def put_callbacks(agent_id, callbacks) when is_binary(agent_id) and is_map(callbacks) do
    ensure_tables!()
    :ets.insert(@callbacks_table, {agent_id, callbacks})
    :ok
  end

  @spec delete_callbacks(String.t()) :: :ok
  def delete_callbacks(agent_id) when is_binary(agent_id) do
    if callbacks_table?(), do: :ets.delete(@callbacks_table, agent_id)
    :ok
  end

  @spec callbacks(String.t()) :: {:ok, map()} | :error
  def callbacks(agent_id) when is_binary(agent_id) do
    with true <- callbacks_table?(),
         [{^agent_id, callbacks}] <- :ets.lookup(@callbacks_table, agent_id) do
      {:ok, callbacks}
    else
      _ -> :error
    end
  end

  @spec delete_runtime_delta_calls(String.t()) :: :ok
  def delete_runtime_delta_calls(agent_id) when is_binary(agent_id) do
    if runtime_delta_table?(), do: :ets.match_delete(@runtime_delta_table, {{agent_id, :_}, :_})
    :ok
  end

  @spec mark_runtime_delta_call(String.t(), String.t() | nil) :: :ok
  def mark_runtime_delta_call(_agent_id, call_id) when call_id in [nil, ""], do: :ok

  def mark_runtime_delta_call(agent_id, call_id) when is_binary(agent_id) do
    ensure_tables!()
    :ets.insert(@runtime_delta_table, {{agent_id, call_id}, true})
    :ok
  end

  @spec runtime_delta_call?(String.t(), String.t() | nil) :: boolean()
  def runtime_delta_call?(_agent_id, call_id) when call_id in [nil, ""], do: false

  def runtime_delta_call?(agent_id, call_id) when is_binary(agent_id) do
    runtime_delta_table?() and :ets.member(@runtime_delta_table, {agent_id, call_id})
  end

  defp ensure_named_table(table) do
    case :ets.whereis(table) do
      :undefined -> :ets.new(table, [:named_table, :public, read_concurrency: true])
      _table -> table
    end
  end

  defp callbacks_table?, do: :ets.whereis(@callbacks_table) != :undefined
  defp runtime_delta_table?, do: :ets.whereis(@runtime_delta_table) != :undefined
end
