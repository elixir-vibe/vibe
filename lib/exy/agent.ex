defmodule Exy.Agent do
  @moduledoc """
  Convenience helpers for starting Exy's Jido-backed coding agent.
  """

  alias Exy.Session.Store

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    configure_model_alias(opts)
    ensure_provider_credentials(opts)

    with {:ok, pid} <- Exy.Jido.start_agent(Exy.Agent.Coding) do
      Jido.AI.set_system_prompt(pid, system_prompt())
      session_id = Keyword.get(opts, :session_id) || Exy.Session.Store.new_id()
      Exy.Session.Processes.register(pid, session_id)
      {:ok, pid}
    end
  end

  @spec ask_sync(pid() | atom(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask_sync(pid, prompt, opts \\ []) do
    session_id =
      Keyword.get(opts, :session_id) || Exy.Session.Processes.session_id(pid) ||
        Exy.Session.Store.new_id()

    Store.append_trajectory(:user_message, %{prompt: prompt}, session_id: session_id)

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

    Store.append_trajectory(:assistant_message, data, session_id: session_id)

    if usage = Exy.Model.Usage.from_response(result) do
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

  defp system_prompt do
    case Exy.Memory.Manager.system_prompt_block() do
      "" -> Exy.Prompts.system()
      memory -> Exy.Prompts.system() <> "\n\n" <> memory
    end
  end

  defp configure_model_alias(opts) do
    current = Application.get_env(:jido_ai, :model_aliases, %{})

    Application.put_env(
      :jido_ai,
      :model_aliases,
      Map.put(current, :exy, Exy.Model.Config.resolve(opts))
    )
  end

  defp ensure_provider_credentials(opts) do
    case Exy.Model.Config.resolve(opts) do
      "openai_codex:" <> _model -> Exy.Auth.Codex.ensure_fresh()
      _model -> :ok
    end
  end
end
