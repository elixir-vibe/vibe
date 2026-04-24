defmodule Exy.Agent do
  @moduledoc """
  Convenience helpers for starting Exy's Jido-backed coding agent.
  """

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    configure_model_alias(opts)
    Jido.AgentServer.start_link(agent: Exy.Agent.Coding)
  end

  @spec ask_sync(pid() | atom(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask_sync(pid, prompt, opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    Exy.Trajectory.Store.append(:user_message, %{prompt: prompt}, session_id: session_id)

    result = Exy.Agent.Coding.ask_sync(pid, prompt, opts)

    data =
      case result do
        {:ok, response} -> %{result: response}
        {:error, reason} -> %{error: inspect(reason)}
      end

    Exy.Trajectory.Store.append(:assistant_message, data, session_id: session_id)
    result
  end

  defp configure_model_alias(opts) do
    model = Keyword.get(opts, :model, System.get_env("EXY_MODEL") || "openai:gpt-4o-mini")

    current = Application.get_env(:jido_ai, :model_aliases, %{})
    Application.put_env(:jido_ai, :model_aliases, Map.put(current, :exy, model))
  end
end
