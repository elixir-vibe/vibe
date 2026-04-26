defmodule Exy.Agent.Streaming do
  @moduledoc false

  use GenServer

  alias Exy.UI.ToolEvent

  @table :exy_agent_streaming_callbacks

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
    end

    :ok
  end

  @spec dispatch(String.t(), map()) :: :ok
  def dispatch(agent_id, data) when is_binary(agent_id) and is_map(data) do
    with true <- table?(), [{^agent_id, callbacks}] <- :ets.lookup(@table, agent_id) do
      data
      |> chunk()
      |> maybe_dispatch_delta(callbacks)
    end

    :ok
  end

  @impl true
  def init(_opts) do
    ensure_table!()
    {:ok, %{}}
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
    |> maybe_put_callback(:tool_started, Keyword.get(opts, :on_tool_started))
    |> maybe_put_callback(:tool_finished, Keyword.get(opts, :on_tool_finished))
  end

  defp maybe_put_callback(callbacks, key, callback) when is_function(callback, 1),
    do: Map.put(callbacks, key, callback)

  defp maybe_put_callback(callbacks, _key, _callback), do: callbacks

  defp chunk(data) do
    type = Map.get(data, :chunk_type) || Map.get(data, "chunk_type") || :content
    text = Map.get(data, :delta) || Map.get(data, "delta") || ""
    {normalize_type(type), text}
  end

  defp safe_status(agent_pid) do
    Jido.AgentServer.status(agent_pid)
  catch
    :exit, _reason -> {:error, :agent_unavailable}
  end

  defp normalize_type(type) when type in [:thinking, "thinking"], do: :thinking
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

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, read_concurrency: true])
      _table -> @table
    end
  end

  defp table?, do: :ets.whereis(@table) != :undefined
end
