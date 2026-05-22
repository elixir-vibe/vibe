defmodule Vibe.Agent.Streaming do
  @moduledoc """
  Dispatches Jido streaming lifecycle signals to per-agent callbacks.

  The server keeps transient callback registrations outside the agent process so
  CLI, TUI, and session callers can attach stream handlers for one request. ReAct
  runtime deltas are ordered by runtime sequence before dispatch because signal
  arrival order is not a reliable transcript order.
  """

  use GenServer

  alias ReqLLM.StreamChunk
  alias Vibe.Agent.Streaming.Registry
  alias Vibe.Tool.Event, as: ToolEvent

  require Vibe.Debug

  @runtime_order_key :runtime_order

  @doc """
  Starts the streaming callback registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Registers stream callbacks for a running Jido agent process.

  Supported callbacks are `:on_result`, `:on_thinking`, `:on_tool_preparing`,
  `:on_tool_started`, and `:on_tool_finished`. Empty callback registrations are
  ignored so callers can pass optional streaming options directly.
  """
  @spec register(pid(), keyword()) :: :ok
  def register(agent_pid, opts) when is_pid(agent_pid) do
    opts
    |> callbacks()
    |> register_callbacks(agent_pid)
  end

  defp register_callbacks(callbacks, _agent_pid) when map_size(callbacks) == 0, do: :ok

  defp register_callbacks(callbacks, agent_pid) do
    with {:ok, agent_id} <- callback_agent_id(agent_pid) do
      store_callbacks(agent_id, callbacks)
    end

    :ok
  end

  defp callback_agent_id(agent_pid) do
    with {:ok, status} <- Jido.AgentServer.status(agent_pid), do: {:ok, status.agent_id}
  end

  defp store_callbacks(agent_id, callbacks) do
    Registry.put_callbacks(agent_id, callbacks)
  end

  @doc """
  Removes callbacks and runtime ordering state for an agent process.
  """
  @spec unregister(pid()) :: :ok
  def unregister(agent_pid) when is_pid(agent_pid) do
    with true <- Process.alive?(agent_pid),
         {:ok, status} <- safe_status(agent_pid) do
      Registry.delete_callbacks(status.agent_id)
      Registry.delete_runtime_delta_calls(status.agent_id)
    end

    :ok
  end

  @doc """
  Dispatches a derived `ai.llm.delta` signal unless runtime deltas own the call.

  Derived deltas do not always carry ordering metadata, so they are suppressed
  after a ReAct runtime delta is observed for the same `{agent_id, call_id}`.
  """
  @spec dispatch(String.t(), StreamChunk.t()) :: :ok
  def dispatch(agent_id, %StreamChunk{} = chunk) when is_binary(agent_id) do
    call_id = call_id(chunk)
    suppressed? = Registry.runtime_delta_call?(agent_id, call_id)

    Vibe.Debug.run do
      Vibe.Agent.Streaming.Trace.record(:derived_llm_delta, %{
        agent_id: agent_id,
        call_id: call_id,
        chunk_type: chunk.type,
        delta: chunk.text || "",
        suppressed?: suppressed?
      })
    end

    unless suppressed? do
      dispatch_chunk(agent_id, chunk)
    end

    :ok
  end

  @doc """
  Dispatches a ReAct runtime delta using its runtime sequence when present.

  Out-of-order runtime arrivals are buffered per `{agent_id, call_id}` until the
  missing sequence arrives or the call finishes.
  """
  @spec dispatch_runtime_delta(String.t(), String.t() | nil, StreamChunk.t()) :: :ok
  def dispatch_runtime_delta(agent_id, call_id, %StreamChunk{} = chunk)
      when is_binary(agent_id) do
    GenServer.call(__MODULE__, {:runtime_delta, agent_id, call_id, runtime_seq(chunk), chunk})
  end

  @doc """
  Flushes and clears buffered runtime deltas for a completed LLM call.
  """
  @spec finish_runtime_call(String.t(), String.t() | nil) :: :ok
  def finish_runtime_call(agent_id, call_id) when is_binary(agent_id) do
    GenServer.call(__MODULE__, {:finish_runtime_call, agent_id, call_id})
  end

  @impl true
  def init(_opts) do
    Registry.ensure_tables!()
    {:ok, %{@runtime_order_key => %{}}}
  end

  @impl true
  def handle_call({:runtime_delta, agent_id, call_id, nil, data}, _from, state) do
    Registry.mark_runtime_delta_call(agent_id, call_id)
    dispatch_chunk(agent_id, data)
    {:reply, :ok, state}
  end

  def handle_call({:runtime_delta, agent_id, call_id, seq, data}, _from, state)
      when is_integer(seq) do
    Registry.mark_runtime_delta_call(agent_id, call_id)
    key = {agent_id, call_id}
    order_state = Map.fetch!(state, @runtime_order_key)
    entry = Map.get(order_state, key, %{next: seq, buffer: %{}})
    entry = put_in(entry.buffer[seq], data)
    {entry, dispatches} = flush_runtime_deltas(entry, [])
    Enum.each(dispatches, &dispatch_chunk(agent_id, &1))
    order_state = Map.put(order_state, key, entry)
    {:reply, :ok, Map.put(state, @runtime_order_key, order_state)}
  end

  def handle_call({:finish_runtime_call, agent_id, call_id}, _from, state) do
    key = {agent_id, call_id}
    order_state = Map.fetch!(state, @runtime_order_key)

    case Map.pop(order_state, key) do
      {nil, order_state} ->
        {:reply, :ok, Map.put(state, @runtime_order_key, order_state)}

      {%{buffer: buffer}, order_state} ->
        buffer
        |> Enum.sort_by(fn {seq, _data} -> seq end)
        |> Enum.each(fn {_seq, data} -> dispatch_chunk(agent_id, data) end)

        {:reply, :ok, Map.put(state, @runtime_order_key, order_state)}
    end
  end

  @doc """
  Sends a streamed tool-parameter update to registered callbacks.
  """
  @spec dispatch_tool_preparing(String.t(), ToolEvent.t()) :: :ok
  def dispatch_tool_preparing(agent_id, %ToolEvent{} = event) when is_binary(agent_id) do
    dispatch_tool(agent_id, :tool_preparing, event)
  end

  @doc """
  Sends a tool-start lifecycle event to registered callbacks.
  """
  @spec dispatch_tool_started(String.t(), ToolEvent.t()) :: :ok
  def dispatch_tool_started(agent_id, %ToolEvent{} = event) when is_binary(agent_id) do
    dispatch_tool(agent_id, :tool_started, event)
  end

  @doc """
  Sends a terminal tool-result lifecycle event to registered callbacks.
  """
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

  defp call_id(%StreamChunk{metadata: metadata}), do: Map.get(metadata, :call_id)
  defp runtime_seq(%StreamChunk{metadata: metadata}), do: Map.get(metadata, :runtime_seq)

  defp flush_runtime_deltas(%{next: next, buffer: buffer} = entry, dispatches) do
    case Map.pop(buffer, next) do
      {nil, _buffer} ->
        {entry, Enum.reverse(dispatches)}

      {data, buffer} ->
        %{entry | next: next + 1, buffer: buffer}
        |> flush_runtime_deltas([data | dispatches])
    end
  end

  defp chunk(%StreamChunk{} = chunk) do
    {normalize_type(chunk.type), chunk.text || ""}
  end

  defp dispatch_chunk(agent_id, %StreamChunk{} = data) do
    with {:ok, callbacks} <- Registry.callbacks(agent_id) do
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
    with {:ok, callbacks} <- Registry.callbacks(agent_id) do
      callbacks[type] && callbacks[type].(event)
    end

    :ok
  end
end
