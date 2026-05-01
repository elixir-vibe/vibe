defmodule Exy.Subagents do
  @moduledoc """
  Supervised subagent orchestration.

  Subagents are Exy jobs, not detached prompts. LLM subagents create child Exy
  sessions so their work can be listed, inspected, cancelled, awaited, and
  attached from the CLI or TUI. Job and schedule metadata is persisted through
  Exy's storage layer.
  """

  alias Exy.Subagents.{Manager, Scheduler}

  @default_timeout_ms 120_000
  @default_max_concurrency 3

  @type task_spec :: %{required(:task) => String.t(), optional(atom()) => term()}

  @spec ask(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(task, opts \\ []) when is_binary(task) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    with {:ok, job} <- start(task, opts),
         {:ok, finished} <- await(job.id, timeout) do
      case finished.status do
        :ok -> {:ok, finished.result}
        :error -> {:error, finished.error}
      end
    end
  end

  @spec start(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def start(task, opts \\ []) when is_binary(task), do: Manager.start_job(task, opts)

  @spec run_many([task_spec() | map()], keyword()) :: {:ok, [map()]} | {:error, term(), [map()]}
  def run_many(specs, opts \\ []) when is_list(specs) do
    max_concurrency =
      Keyword.get(opts, :max_concurrency, min(length(specs), @default_max_concurrency))

    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    specs
    |> Task.async_stream(&run_spec(&1, opts),
      max_concurrency: max_concurrency,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Enum.reduce({:ok, []}, fn
      {:ok, {:ok, result}}, {:ok, acc} -> {:ok, [result | acc]}
      {:ok, {:ok, result}}, {:error, reason, acc} -> {:error, reason, [result | acc]}
      {:ok, {:error, reason}}, {:ok, acc} -> {:error, reason, acc}
      {:ok, {:error, reason}}, {:error, _old, acc} -> {:error, reason, acc}
      {:exit, reason}, {:ok, acc} -> {:error, reason, acc}
      {:exit, reason}, {:error, _old, acc} -> {:error, reason, acc}
    end)
    |> case do
      {:ok, results} -> {:ok, Enum.reverse(results)}
      {:error, reason, results} -> {:error, reason, Enum.reverse(results)}
    end
  end

  @spec await(String.t(), timeout()) :: {:ok, term()} | {:error, term()}
  def await(id, timeout \\ @default_timeout_ms) do
    started = System.monotonic_time(:millisecond)
    await_loop(id, timeout, started)
  end

  @spec jobs() :: [term()]
  def jobs, do: Manager.jobs()

  @spec status(String.t()) :: {:ok, term()} | {:error, term()}
  def status(id), do: Manager.status(id)

  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(id), do: Manager.cancel(id)

  @spec result(String.t()) :: {:ok, term()} | {:error, term()}
  def result(id), do: Manager.result(id)

  @spec schedule(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def schedule(task, opts \\ []), do: Scheduler.schedule(task, opts)

  @spec scheduled() :: [term()]
  def scheduled, do: Scheduler.scheduled()

  @spec unschedule(String.t()) :: :ok | {:error, term()}
  def unschedule(id), do: Scheduler.unschedule(id)

  @spec active() :: [map()]
  def active do
    Registry.select(Exy.Registry, [
      {{{:subagent, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.map(fn {id, pid, meta} ->
      Map.merge(Map.new(meta), %{id: id, pid: inspect(pid)})
    end)
  end

  defp run_spec(%{run: run} = spec, _opts) when is_function(run, 1) do
    run_function_spec(spec)
  end

  defp run_spec(%{task: task} = spec, opts) when is_binary(task) do
    task_opts = Keyword.merge(opts, Map.to_list(Map.delete(spec, :task)))

    with {:ok, job} <- start(task, task_opts),
         {:ok, result} <- await(job.id, Keyword.get(task_opts, :timeout, @default_timeout_ms)) do
      {:ok, Map.from_struct(result)}
    end
  end

  defp run_spec(%{"task" => task} = spec, opts) when is_binary(task) do
    atom_spec = Map.new(spec, fn {key, value} -> {String.to_existing_atom(key), value} end)
    run_spec(atom_spec, opts)
  rescue
    ArgumentError -> {:error, :invalid_task_spec}
  end

  defp run_spec(spec, _opts), do: {:error, {:invalid_task_spec, spec}}

  defp run_function_spec(spec) do
    id = Map.get(spec, :id, new_id())
    goal = Map.get(spec, :goal) || Map.get(spec, :task)
    started_at = System.monotonic_time(:millisecond)

    Exy.Session.Store.append_trajectory(:subagent_started, %{
      id: id,
      role: Map.get(spec, :role),
      goal: goal
    })

    try do
      result = %{
        id: id,
        role: Map.get(spec, :role, :worker),
        goal: goal,
        status: :ok,
        result: spec.run.(spec),
        duration_ms: System.monotonic_time(:millisecond) - started_at
      }

      Exy.Session.Store.append_trajectory(:subagent_finished, result)
      {:ok, result}
    rescue
      exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
    catch
      kind, reason -> {:error, Exception.format(kind, reason, __STACKTRACE__)}
    end
  end

  defp await_loop(id, timeout, started) do
    case Manager.status(id) do
      {:ok, %{status: status} = job} when status in [:ok, :error] ->
        {:ok, job}

      {:ok, _job} ->
        if System.monotonic_time(:millisecond) - started >= timeout do
          {:error, :timeout}
        else
          Process.sleep(50)
          await_loop(id, timeout, started)
        end

      error ->
        error
    end
  end

  defp new_id do
    8 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
