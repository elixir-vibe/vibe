defmodule Vibe.Eval do
  @moduledoc """
  Runtime Elixir evaluation with captured IO, timeouts, and session state.

  Eval is Vibe's main control plane for agents. The model-facing `eval` tool can
  call ordinary Elixir APIs inside the running Vibe VM, which keeps the external
  tool surface small while still exposing commands, telemetry, storage, plugins,
  sessions, subagents, AST, and LSP helpers.

  Use `run/2` when evaluation should persist variables, aliases, imports, and
  requires for a session. Use `once/2` for one-off in-process evaluation that
  should not keep state. Eval sessions preload aliases such as `Cmd` for
  `Vibe.Command` and `MD` for `Vibe.MD`.
  """

  alias Vibe.Eval.{Evaluator, Result}

  @default_timeout_ms 30_000

  @type result :: {:ok, Result.t()} | {:error, String.t()}

  @spec run(String.t(), keyword()) :: result()
  def run(code, opts) when is_binary(code) do
    case Keyword.fetch(opts, :session_id) do
      {:ok, session_id} when is_binary(session_id) ->
        evaluate_with_timeout(code, session_id, true, opts)

      _missing ->
        {:error,
         "session_id is required for stateful eval; use Vibe.Eval.once/2 for one-off evaluation"}
    end
  end

  @spec once(String.t(), keyword()) :: result()
  def once(code, opts \\ []) when is_binary(code) do
    session_id = "__eval_#{System.unique_integer([:positive])}"
    evaluate_with_timeout(code, session_id, false, opts)
  end

  @spec bindings(String.t()) :: {:ok, [Evaluator.binding_info()]} | {:error, String.t()}
  def bindings(session_id) when is_binary(session_id) do
    with {:ok, evaluator} <- evaluator(session_id, true) do
      {:ok, Evaluator.bindings(evaluator)}
    end
  end

  @spec forget(String.t(), [atom() | String.t()] | atom() | String.t()) ::
          :ok | {:error, String.t()}
  def forget(session_id, names) when is_binary(session_id) do
    with {:ok, names} <- normalize_names(names),
         {:ok, evaluator} <- evaluator(session_id, true) do
      Evaluator.forget(evaluator, names)
    end
  end

  @spec reset(String.t()) :: :ok | {:error, String.t()}
  def reset(session_id) when is_binary(session_id) do
    with {:ok, evaluator} <- evaluator(session_id, true) do
      Evaluator.reset(evaluator)
    end
  end

  @spec cancel(String.t()) :: :ok
  def cancel(session_id) when is_binary(session_id) do
    stop_evaluator(session_id)
    Vibe.Command.Streaming.cancel_session(session_id)
    :ok
  end

  defp evaluate_with_timeout(code, session_id, persist?, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    caller = self()

    {pid, ref} =
      spawn_monitor(fn ->
        result = evaluate(session_id, code, persist?)
        unless persist?, do: stop_evaluator(session_id)
        send(caller, {:vibe_eval_result, self(), result})
      end)

    receive do
      {:vibe_eval_result, ^pid, result} ->
        Process.demonitor(ref, [:flush])
        result

      {:DOWN, ^ref, :process, ^pid, reason} ->
        {:error, "evaluation process exited: #{Exception.format_exit(reason)}"}
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :brutal_kill)
        stop_evaluator(session_id)
        {:error, "evaluation timed out after #{timeout}ms"}
    end
  end

  defp evaluate(session_id, code, persist?) do
    with {:ok, evaluator} <- evaluator(session_id, persist?) do
      Evaluator.evaluate(evaluator, code)
    end
  end

  defp normalize_names(names) when is_atom(names) or is_binary(names),
    do: normalize_names([names])

  defp normalize_names(names) when is_list(names) do
    names
    |> Enum.reduce_while({:ok, []}, fn
      name, {:ok, acc} when is_atom(name) ->
        {:cont, {:ok, [name | acc]}}

      name, {:ok, acc} when is_binary(name) ->
        {:cont, {:ok, [String.to_existing_atom(name) | acc]}}

      name, {:ok, _acc} ->
        {:halt, {:error, "invalid binding name: #{inspect(name)}"}}
    end)
    |> case do
      {:ok, names} -> {:ok, Enum.reverse(names)}
      error -> error
    end
  rescue
    ArgumentError -> {:error, "unknown binding name"}
  end

  defp evaluator(session_id, persist?) do
    case Registry.lookup(Vibe.Registry, {:eval, session_id}) do
      [{pid, _value}] when is_pid(pid) ->
        if Process.alive?(pid), do: {:ok, pid}, else: start_evaluator(session_id, persist?)

      [] ->
        start_evaluator(session_id, persist?)
    end
  end

  defp start_evaluator(session_id, persist?) do
    DynamicSupervisor.start_child(
      Vibe.Eval.Supervisor,
      %{
        id: {Evaluator, session_id},
        start: {Evaluator, :start_link, [[session_id: session_id, persist?: persist?]]}
      }
    )
    |> case do
      {:ok, pid} -> {:ok, pid}
      {:ok, pid, _info} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, "failed to start evaluator: #{inspect(reason)}"}
    end
  end

  defp stop_evaluator(session_id) do
    with [{pid, _value}] <- Registry.lookup(Vibe.Registry, {:eval, session_id}) do
      DynamicSupervisor.terminate_child(Vibe.Eval.Supervisor, pid)
    end

    :ok
  end
end
