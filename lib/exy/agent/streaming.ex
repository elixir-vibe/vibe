defmodule Exy.Agent.Streaming do
  @moduledoc false

  use GenServer

  alias Exy.UI.ToolEvent

  require Exy.Debug

  @table :exy_agent_streaming_callbacks
  @runtime_delta_table :exy_agent_streaming_runtime_delta_calls

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec register(pid(), keyword()) :: :ok
  def register(agent_pid, opts) when is_pid(agent_pid) do
    callbacks = callbacks(opts)

    if map_size(callbacks) == 0 do
      :ok
    else
      with {:ok, status} <- Jido.AgentServer.status(agent_pid) do
        ensure_table!()
        :ets.insert(@table, {status.agent_id, callbacks})
      end

      :ok
    end
  end

  @spec unregister(pid()) :: :ok
  def unregister(agent_pid) when is_pid(agent_pid) do
    with true <- Process.alive?(agent_pid),
         {:ok, status} <- safe_status(agent_pid),
         true <- table?() do
      :ets.delete(@table, status.agent_id)
      delete_runtime_delta_calls(status.agent_id)
    end

    :ok
  end

  @spec dispatch(String.t(), map()) :: :ok
  def dispatch(agent_id, data) when is_binary(agent_id) and is_map(data) do
    call_id = call_id(data)
    suppressed? = runtime_delta_call?(agent_id, call_id)

    Exy.Debug.run do
      Exy.Agent.Streaming.Trace.record(:derived_llm_delta, %{
        agent_id: agent_id,
        call_id: call_id,
        chunk_type: Map.get(data, :chunk_type) || Map.get(data, "chunk_type"),
        delta: Map.get(data, :delta) || Map.get(data, "delta") || "",
        suppressed?: suppressed?
      })
    end

    unless suppressed? do
      dispatch_chunk(agent_id, data)
    end

    :ok
  end

  @spec dispatch_runtime_delta(String.t(), String.t() | nil, map()) :: :ok
  def dispatch_runtime_delta(agent_id, call_id, data) when is_binary(agent_id) and is_map(data) do
    mark_runtime_delta_call(agent_id, call_id)
    dispatch_chunk(agent_id, data)
  end

  @impl true
  def init(_opts) do
    ensure_table!()
    {:ok, %{}}
  end

  @spec dispatch_tool_preparing(String.t(), ToolEvent.t()) :: :ok
  def dispatch_tool_preparing(agent_id, %ToolEvent{} = event) when is_binary(agent_id) do
    dispatch_tool(agent_id, :tool_preparing, event)
  end

  @spec dispatch_tool_started(String.t(), ToolEvent.t()) :: :ok
  def dispatch_tool_started(agent_id, %ToolEvent{} = event) when is_binary(agent_id) do
    dispatch_tool(agent_id, :tool_started, event)
  end

  @spec dispatch_tool_finished(String.t(), ToolEvent.t()) :: :ok
  def dispatch_tool_finished(agent_id, %ToolEvent{} = event) when is_binary(agent_id) do
    dispatch_tool(agent_id, :tool_finished, event)
  end

  defp callbacks(opts) do
    %{}
    |> maybe_put_callback(:content, Keyword.get(opts, :on_result))
    |> maybe_put_callback(:thinking, Keyword.get(opts, :on_thinking))
    |> maybe_put_callback(:tool_preparing, Keyword.get(opts, :on_tool_preparing))
    |> maybe_put_callback(:tool_started, Keyword.get(opts, :on_tool_started))
    |> maybe_put_callback(:tool_finished, Keyword.get(opts, :on_tool_finished))
  end

  defp maybe_put_callback(callbacks, key, callback) when is_function(callback, 1),
    do: Map.put(callbacks, key, callback)

  defp maybe_put_callback(callbacks, _key, _callback), do: callbacks

  defp call_id(data), do: Map.get(data, :call_id) || Map.get(data, "call_id")

  defp chunk(data) do
    type = Map.get(data, :chunk_type, :content)
    text = Map.get(data, :delta, "")
    {normalize_type(type), text}
  end

  defp dispatch_chunk(agent_id, data) do
    with true <- table?(), [{^agent_id, callbacks}] <- :ets.lookup(@table, agent_id) do
      data
      |> chunk()
      |> maybe_dispatch_delta(callbacks)
    end

    :ok
  end

  defp safe_status(agent_pid) do
    Jido.AgentServer.status(agent_pid)
  catch
    :exit, _reason -> {:error, :agent_unavailable}
  end

  defp normalize_type(:thinking), do: :thinking
  defp normalize_type(_type), do: :content

  defp maybe_dispatch_delta({_type, ""}, _callbacks), do: :ok

  defp maybe_dispatch_delta({type, text}, callbacks),
    do: callbacks[type] && callbacks[type].(text)

  defp dispatch_tool(agent_id, type, %ToolEvent{} = event) do
    with true <- table?(), [{^agent_id, callbacks}] <- :ets.lookup(@table, agent_id) do
      callbacks[type] && callbacks[type].(event)
    end

    :ok
  end

  defp delete_runtime_delta_calls(agent_id) do
    if runtime_delta_table?(), do: :ets.match_delete(@runtime_delta_table, {{agent_id, :_}, :_})
    :ok
  end

  defp mark_runtime_delta_call(_agent_id, call_id) when call_id in [nil, ""], do: :ok

  defp mark_runtime_delta_call(agent_id, call_id) do
    ensure_table!()
    :ets.insert(@runtime_delta_table, {{agent_id, call_id}, true})
    :ok
  end

  defp runtime_delta_call?(_agent_id, call_id) when call_id in [nil, ""], do: false

  defp runtime_delta_call?(agent_id, call_id) do
    runtime_delta_table?() and :ets.member(@runtime_delta_table, {agent_id, call_id})
  end

  defp ensure_table! do
    ensure_named_table(@table)
    ensure_named_table(@runtime_delta_table)
  end

  defp ensure_named_table(table) do
    case :ets.whereis(table) do
      :undefined -> :ets.new(table, [:named_table, :public, read_concurrency: true])
      _table -> table
    end
  end

  defp table?, do: :ets.whereis(@table) != :undefined
  defp runtime_delta_table?, do: :ets.whereis(@runtime_delta_table) != :undefined
end
