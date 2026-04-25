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

    result =
      try do
        Exy.Agent.Streaming.register(pid, opts)
        Exy.Agent.Coding.ask_sync(pid, prompt, opts)
      after
        Exy.Agent.Streaming.unregister(pid)
      end

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
