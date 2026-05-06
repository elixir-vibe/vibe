defmodule Vibe.Agent do
  @moduledoc """
  Convenience helpers for starting Vibe's Jido-backed coding agent.
  """

  alias Vibe.Agent.Options
  alias Vibe.Session.Store

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    with {:ok, opts} <- Options.resolve(opts),
         :ok <- Options.ensure_provider_credentials(opts) do
      Options.configure_model_alias(opts)

      with {:ok, pid} <- Vibe.Jido.start_agent(Vibe.Agent.Coding) do
        Jido.AI.set_system_prompt(pid, Options.system_prompt(opts))
        session_id = Keyword.get(opts, :session_id) || Vibe.Session.Store.new_id()
        Vibe.Session.Processes.register(pid, session_id)
        {:ok, pid}
      end
    end
  end

  @spec ask(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(prompt, opts \\ []) when is_binary(prompt) do
    with {:ok, opts} <- Options.resolve(opts),
         {:ok, pid} <- start_link(opts) do
      try do
        ask_sync(pid, prompt, opts)
      after
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    end
  end

  @spec ask_sync(pid() | atom(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask_sync(pid, prompt, opts \\ []) do
    session_id =
      Keyword.get(opts, :session_id) || Vibe.Session.Processes.session_id(pid) ||
        Vibe.Session.Store.new_id()

    Store.append_trajectory(:user_message, %{prompt: prompt}, session_id: session_id)

    result =
      try do
        Vibe.Agent.Streaming.register(pid, opts)
        Vibe.Agent.Coding.ask_sync(pid, prompt, opts)
      after
        Vibe.Agent.Streaming.unregister(pid)
      end

    result = enrich_result_usage(result, pid)

    data =
      case result do
        {:ok, response} -> %{result: response}
        {:error, reason} -> %{error: inspect(reason)}
      end

    Store.append_trajectory(:assistant_message, data, session_id: session_id)

    if usage = Vibe.Model.Usage.from_response(result) do
      Store.append_trajectory(:llm_usage, usage, session_id: session_id)
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
    with true <- Process.alive?(pid), {:ok, status} <- safe_status(pid) do
      get_in(status.raw_state, [:__strategy__, :usage]) || status.snapshot.details[:usage]
    else
      _other -> nil
    end
  end

  defp safe_status(pid) do
    Jido.AgentServer.status(pid)
  catch
    :exit, _reason -> {:error, :agent_unavailable}
  end
end
