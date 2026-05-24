defmodule Vibe.Session.EvalLifecycle do
  @moduledoc "Lifecycle for user-initiated Elixir eval executions."

  alias Vibe.Event

  @type emit_fun :: (map(), Event.t() -> map())

  @spec submit(map(), String.t(), boolean(), emit_fun()) :: map()
  def submit(state, code, include_context?, emit) when is_binary(code) do
    id = "eval-" <> Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
    session_id = state.state.session_id
    parent = self()

    {:ok, pid} =
      Task.Supervisor.start_child(Vibe.TaskSupervisor, fn ->
        started_mono = System.monotonic_time(:millisecond)
        result = Vibe.Eval.run(code, session_id: session_id)
        duration_ms = max(System.monotonic_time(:millisecond) - started_mono, 0)
        send(parent, {:eval_expression_finished, id, duration_ms, result})
      end)

    eval = %{pid: pid, code: code, include_context?: include_context?}

    state
    |> Map.update!(:eval_tasks, &Map.put(&1, id, eval))
    |> emit.(
      Event.new(
        :eval_execution_started,
        session_id,
        Vibe.Event.EvalExecution.started(
          id: id,
          code: code,
          include_context?: include_context?
        )
      )
    )
  end

  @spec cancel(map(), emit_fun()) :: map()
  def cancel(%{eval_tasks: eval_tasks} = state, _emit) when map_size(eval_tasks) == 0, do: state

  def cancel(state, emit) do
    Vibe.Eval.cancel(state.state.session_id)

    Enum.each(state.eval_tasks, fn {_id, %{pid: pid}} ->
      if is_pid(pid) and Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    Enum.reduce(state.eval_tasks, %{state | eval_tasks: %{}}, fn {id, eval}, acc ->
      emit.(
        acc,
        Event.new(
          :eval_execution_finished,
          state.state.session_id,
          finished(id, Map.get(eval, :code), Map.get(eval, :include_context?, true), 0, {
            :error,
            "Cancelled."
          })
        )
      )
    end)
  end

  @spec record_result(map(), String.t(), non_neg_integer(), Vibe.Eval.result(), emit_fun()) ::
          map()
  def record_result(state, id, duration_ms, result, emit) do
    case Map.pop(state.eval_tasks, id) do
      {nil, _eval_tasks} ->
        state

      {%{code: code, include_context?: include_context?}, eval_tasks} ->
        data = finished(id, code, include_context?, duration_ms, result)

        state
        |> Map.put(:eval_tasks, eval_tasks)
        |> emit.(Event.new(:eval_execution_finished, state.state.session_id, data))
    end
  end

  defp finished(id, code, include_context?, duration_ms, {:ok, result}) do
    output = Vibe.Eval.Result.to_tool_output(result)

    Vibe.Event.EvalExecution.finished(
      id: id,
      code: code,
      include_context?: include_context?,
      status: :ok,
      output: Map.get(output, :output),
      output_format: Map.get(output, :output_format),
      output_parts: Map.get(output, :output_parts),
      output_truncation: Map.get(output, :output_truncation),
      duration_ms: duration_ms
    )
  end

  defp finished(id, code, include_context?, duration_ms, {:error, error}) do
    Vibe.Event.EvalExecution.finished(
      id: id,
      code: code,
      include_context?: include_context?,
      status: :error,
      error: error,
      duration_ms: duration_ms
    )
  end
end
