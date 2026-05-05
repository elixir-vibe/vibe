defmodule Exy.Model.WebSocketSession do
  @moduledoc """
  Caches reusable ReqLLM Responses WebSocket sessions per Exy session and model.

  The cache is deliberately opt-in. Callers request a session only after provider
  options enable OpenAI Responses WebSocket reuse, and failures are reported to the
  caller so it can fall back to ordinary streaming or surface a provider error.
  """

  use GenServer

  @type key :: {String.t(), String.t()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec get(term(), keyword(), String.t()) :: {:ok, pid()} | {:error, term()}
  def get(model, request_opts, session_id) when is_list(request_opts) and is_binary(session_id) do
    GenServer.call(__MODULE__, {:get, model, request_opts, session_id}, :infinity)
  end

  @spec close_session(String.t()) :: :ok
  def close_session(session_id) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:close_session, session_id})
  end

  @impl true
  def init(_opts), do: {:ok, %{sessions: %{}, refs: %{}}}

  @impl true
  def handle_call({:get, model, request_opts, session_id}, _from, state) do
    with {:ok, model} <- resolve_model(model),
         key <- key(session_id, model),
         {:ok, pid, state} <- get_or_start(key, model, request_opts, state) do
      {:reply, {:ok, pid}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:close_session, session_id}, _from, state) do
    {closing, keeping} =
      Enum.split_with(state.sessions, fn {{stored_session_id, _model_id}, _pid} ->
        stored_session_id == session_id
      end)

    Enum.each(closing, fn {_key, pid} -> close(pid) end)

    closing_keys = MapSet.new(closing, fn {key, _pid} -> key end)
    refs = Map.reject(state.refs, fn {_ref, key} -> MapSet.member?(closing_keys, key) end)

    {:reply, :ok, %{state | sessions: Map.new(keeping), refs: refs}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.refs, ref) do
      {nil, refs} ->
        {:noreply, %{state | refs: refs}}

      {key, refs} ->
        {:noreply, %{state | refs: refs, sessions: Map.delete(state.sessions, key)}}
    end
  end

  defp get_or_start(key, model, request_opts, state) do
    case Map.get(state.sessions, key) do
      pid when is_pid(pid) ->
        if Process.alive?(pid),
          do: {:ok, pid, state},
          else: start_session(key, model, request_opts, state)

      nil ->
        start_session(key, model, request_opts, state)
    end
  end

  defp start_session(key, model, request_opts, state) do
    with {:ok, pid} <- start_provider_session(model, request_opts) do
      ref = Process.monitor(pid)
      emit_started(elem(key, 0), model, pid)

      state = %{
        state
        | sessions: Map.put(state.sessions, key, pid),
          refs: Map.put(state.refs, ref, key)
      }

      {:ok, pid, state}
    end
  end

  defp start_provider_session(%LLMDB.Model{provider: :openai} = model, opts) do
    ReqLLM.Providers.OpenAI.WebSocket.start_responses_session(model, opts)
  end

  defp start_provider_session(%LLMDB.Model{provider: :openai_codex} = model, opts) do
    ReqLLM.Providers.OpenAICodex.start_responses_session(model, opts)
  end

  defp start_provider_session(%LLMDB.Model{provider: provider}, _opts) do
    {:error, {:unsupported_reusable_websocket_provider, provider}}
  end

  defp resolve_model(%LLMDB.Model{} = model), do: {:ok, model}

  defp resolve_model(model) when is_binary(model) do
    ReqLLM.model(model)
  end

  defp resolve_model(model), do: {:error, {:invalid_websocket_model, model}}

  defp key(session_id, %LLMDB.Model{} = model), do: {session_id, model.id}

  defp close(pid) when is_pid(pid) do
    if Code.ensure_loaded?(ReqLLM.Streaming.WebSocketSession) do
      ReqLLM.Streaming.WebSocketSession.close(pid)
    else
      Process.exit(pid, :normal)
    end
  catch
    :exit, _reason -> :ok
  end

  defp emit_started(session_id, %LLMDB.Model{} = model, pid) do
    :telemetry.execute(
      [:exy, :model, :websocket_session, :started],
      %{count: 1},
      %{session_id: session_id, model: model.id, provider: model.provider, pid: inspect(pid)}
    )
  end
end
