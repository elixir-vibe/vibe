defmodule Exy.Agent do
  @moduledoc """
  Convenience helpers for starting Exy's Jido-backed coding agent.
  """

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    configure_model_alias(opts)

    with {:ok, pid} <- Jido.AgentServer.start_link(agent: Exy.Agent.Coding) do
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

    result = Exy.Agent.Coding.ask_sync(pid, prompt, opts)

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

  defp configure_model_alias(opts) do
    current = Application.get_env(:jido_ai, :model_aliases, %{})

    Application.put_env(
      :jido_ai,
      :model_aliases,
      Map.put(current, :exy, Exy.LLM.Model.resolve(opts))
    )
  end
end
