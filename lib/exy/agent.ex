defmodule Exy.Agent do
  @moduledoc """
  Convenience helpers for starting Exy's Jido-backed coding agent.
  """

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    configure_model_alias(opts)

    with {:ok, pid} <- Exy.Jido.start_agent(Exy.Agent.Coding) do
      session_id = Keyword.get(opts, :session_id) || Exy.Session.new_id()
      Exy.Session.Processes.register(pid, session_id)
      {:ok, pid}
    end
  end

  @spec ask_sync(pid() | atom(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask_sync(pid, prompt, opts \\ []) do
    session_id =
      Keyword.get(opts, :session_id) || Exy.Session.Processes.session_id(pid) ||
        Exy.Session.new_id()

    Exy.Trajectory.Store.append(:user_message, %{prompt: prompt}, session_id: session_id)

    monitor = maybe_start_stream_monitor(pid, opts)
    result = Exy.Agent.Coding.ask_sync(pid, prompt, opts)
    stop_stream_monitor(monitor)
    result = enrich_result_usage(result, pid)

    data =
      case result do
        {:ok, response} -> %{result: response}
        {:error, reason} -> %{error: inspect(reason)}
      end

    Exy.Trajectory.Store.append(:assistant_message, data, session_id: session_id)

    if usage = Exy.LLM.Usage.from_response(result) do
      Exy.Trajectory.Store.append(:llm_usage, usage, session_id: session_id)
    end

    result
  end

  defp maybe_start_stream_monitor(pid, opts) do
    on_result = Keyword.get(opts, :on_result)
    on_thinking = Keyword.get(opts, :on_thinking)

    if is_function(on_result, 1) or is_function(on_thinking, 1) do
      parent = self()
      ref = make_ref()
      task = Task.async(fn -> poll_stream(pid, ref, parent, on_result, on_thinking, "", "") end)
      {ref, task}
    end
  end

  defp stop_stream_monitor(nil), do: :ok

  defp stop_stream_monitor({ref, task}) do
    send(task.pid, {:stop_stream_monitor, ref})
    Task.shutdown(task, 100)
    :ok
  end

  defp poll_stream(pid, ref, owner, on_result, on_thinking, last_text, last_thinking) do
    receive do
      {:stop_stream_monitor, ^ref} ->
        :ok
    after
      50 ->
        {text, thinking} = stream_snapshot(pid)
        emit_delta(owner, on_result, last_text, text)
        emit_delta(owner, on_thinking, last_thinking, thinking)
        poll_stream(pid, ref, owner, on_result, on_thinking, text, thinking)
    end
  end

  defp stream_snapshot(pid) do
    case Jido.AgentServer.status(pid) do
      {:ok, status} ->
        strategy = Map.get(status.raw_state, :__strategy__, %{})

        {Map.get(strategy, :streaming_text, "") || "",
         Map.get(strategy, :streaming_thinking, "") || ""}

      _other ->
        {"", ""}
    end
  end

  defp emit_delta(_owner, callback, previous, current) when is_function(callback, 1) do
    if String.starts_with?(current, previous) and byte_size(current) > byte_size(previous) do
      delta = binary_part(current, byte_size(previous), byte_size(current) - byte_size(previous))
      callback.(delta)
    end
  end

  defp emit_delta(_owner, _callback, _previous, _current), do: :ok

  defp enrich_result_usage({:ok, response}, pid) do
    case agent_usage(pid) do
      usage when is_map(usage) and map_size(usage) > 0 -> {:ok, %{output: response, usage: usage}}
      _usage -> {:ok, response}
    end
  end

  defp enrich_result_usage(result, _pid), do: result

  defp agent_usage(pid) do
    case Jido.AgentServer.status(pid) do
      {:ok, status} ->
        get_in(status.raw_state, [:__strategy__, :usage]) || status.snapshot.details[:usage]

      _other ->
        nil
    end
  end

  defp configure_model_alias(opts) do
    current = Application.get_env(:jido_ai, :model_aliases, %{})

    Application.put_env(
      :jido_ai,
      :model_aliases,
      Map.put(current, :exy, Exy.LLM.Model.resolve(opts))
    )
  end
end
