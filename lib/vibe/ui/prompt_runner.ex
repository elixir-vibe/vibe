defmodule Vibe.UI.PromptRunner do
  @moduledoc "Task-based prompt execution for interactive sessions."
  @default_prompt_timeout_ms 86_400_000

  @type ask_fun :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @spec start(ask_fun(), String.t(), keyword(), pid(), reference()) :: {:ok, pid()}
  def start(ask_fun, text, ask_opts, parent, ref) do
    Task.start(fn -> send(parent, {:prompt_result, ref, safe_ask(ask_fun, text, ask_opts)}) end)
  end

  @spec cancel(pid() | nil, pid() | nil) :: :ok
  def cancel(active_agent, prompt_task) do
    if is_pid(active_agent) and Process.alive?(active_agent) do
      _ = Vibe.Agent.Coding.cancel(active_agent, reason: :user_cancelled)
      GenServer.stop(active_agent, :normal, 100)
    end

    if is_pid(prompt_task) and Process.alive?(prompt_task) do
      Process.exit(prompt_task, :kill)
    end

    :ok
  end

  @spec safe_ask(ask_fun(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def safe_ask(ask_fun, text, opts) do
    ask_fun.(text, opts)
  rescue
    exception -> {:error, {:exception, :error, exception, __STACKTRACE__}}
  catch
    kind, reason -> {:error, {:exception, kind, reason, __STACKTRACE__}}
  end

  @spec default_ask(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def default_ask(text, opts) do
    Vibe.Application.configure_dependency_logging()

    agent_opts =
      Keyword.take(opts, [
        :model,
        :role,
        :system,
        :allowed_tools,
        :provider_options,
        :effort,
        :session_id
      ])

    ask_opts = opts |> Vibe.Session.agent_ask_opts() |> Keyword.delete(:stream_owner)

    with {:ok, agent} <- Vibe.start_link(agent_opts) do
      notify_stream_owner(opts[:stream_owner], agent)

      try do
        # Match the coding agent's one-day tool ceiling so long installs or test
        # suites fail at the command/eval layer, not at the outer prompt await.
        Vibe.ask(agent, text, Keyword.put_new(ask_opts, :timeout, @default_prompt_timeout_ms))
      after
        if Process.alive?(agent), do: GenServer.stop(agent)
      end
    end
  end

  defp notify_stream_owner({owner, ref}, agent) when is_pid(owner) and is_reference(ref) do
    send(owner, {:active_agent, ref, agent})
  end

  defp notify_stream_owner(_owner, _agent), do: :ok
end
