defmodule Exy.Subagents do
  @moduledoc """
  OTP-native subagent runner.

  This first implementation runs Elixir functions as supervised workers. The
  same process-tree, budget, and telemetry shape can later wrap Jido/LLM agents.
  """

  @type spec :: %{
          optional(:id) => term(),
          optional(:role) => atom(),
          required(:goal) => String.t(),
          required(:run) => (map() -> term())
        }

  @spec run_many([spec()], keyword()) :: {:ok, [map()]} | {:error, term(), [map()]}
  def run_many(specs, opts \\ []) when is_list(specs) do
    max_concurrency = Keyword.get(opts, :max_concurrency, min(length(specs), 3))
    timeout = Keyword.get(opts, :timeout, 60_000)
    budget = Exy.Budget.new(opts)

    specs
    |> Task.async_stream(&run_one(&1, budget),
      max_concurrency: max_concurrency,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Enum.reduce({:ok, []}, fn
      {:ok, result}, {:ok, acc} -> {:ok, [result | acc]}
      {:ok, result}, {:error, reason, acc} -> {:error, reason, [result | acc]}
      {:exit, reason}, {:ok, acc} -> {:error, reason, acc}
      {:exit, reason}, {:error, _old, acc} -> {:error, reason, acc}
    end)
    |> case do
      {:ok, results} -> {:ok, Enum.reverse(results)}
      {:error, reason, results} -> {:error, reason, Enum.reverse(results)}
    end
  end

  @spec active() :: [map()]
  def active do
    Registry.select(Exy.Registry, [{{{:subagent, :_}, :_, :_}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {{:subagent, id}, pid, meta} ->
      Map.merge(Map.new(meta), %{id: id, pid: inspect(pid)})
    end)
  end

  defp run_one(spec, budget) do
    id = Map.get(spec, :id, new_id())
    parent = self()

    child_spec = %{
      id: {:exy_subagent, id},
      start: {Exy.Subagents.Worker, :start_link, [Map.put(spec, :id, id), parent, budget]},
      restart: :temporary
    }

    started_at = System.monotonic_time(:millisecond)

    {:ok, pid} = DynamicSupervisor.start_child(Exy.Subagents.Supervisor, child_spec)
    ref = Process.monitor(pid)

    receive do
      {:exy_subagent_result, ^id, result} ->
        Process.demonitor(ref, [:flush])
        result

      {:DOWN, ^ref, :process, ^pid, reason} ->
        %{
          id: id,
          role: Map.get(spec, :role, :worker),
          goal: spec.goal,
          status: :error,
          error: Exception.format_exit(reason),
          duration_ms: System.monotonic_time(:millisecond) - started_at
        }
    end
  end

  defp new_id do
    8 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
