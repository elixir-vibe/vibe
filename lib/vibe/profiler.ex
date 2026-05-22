defmodule Vibe.Profiler do
  @moduledoc """
  Thin profiling helpers callable through `Vibe.Eval`.

  These helpers intentionally return compact summaries. Raw profiler output can
  be redirected to artifact files by the caller when needed.
  """

  @default_top_calls_limit 25
  @default_timeout_ms 30_000
  @default_growth_duration_ms 1_000

  @spec cprof((-> term()), keyword()) :: map()
  def cprof(fun, opts \\ []) when is_function(fun, 0) do
    modules = Keyword.get(opts, :modules, :all)
    call(:cprof, :start, [])
    started_at = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      total = call(:cprof, :pause, [])
      calls = collect_cprof(modules, Keyword.get(opts, :limit, @default_top_calls_limit))

      %{
        profiler: :cprof,
        duration_ms: System.monotonic_time(:millisecond) - started_at,
        total_calls: total,
        result: safe_inspect(result),
        top_calls: calls
      }
    after
      call(:cprof, :stop, [])
    end
  end

  @spec eprof((-> term()), keyword()) :: map()
  def eprof(fun, opts \\ []) when is_function(fun, 0) do
    monitored_profile(:eprof, Keyword.get(opts, :timeout, @default_timeout_ms), fn ->
      call(:eprof, :start, [])
      call(:eprof, :start_profiling, [[self()]])
      started_at = System.monotonic_time(:millisecond)
      result = fun.()
      call(:eprof, :stop_profiling, [])
      analysis = capture_io(fn -> call(:eprof, :analyze, []) end)
      call(:eprof, :stop, [])

      profile_result(:eprof, started_at, result, analysis)
    end)
  end

  @spec fprof((-> term()), keyword()) :: map()
  def fprof(fun, opts \\ []) when is_function(fun, 0) do
    monitored_profile(:fprof, Keyword.get(opts, :timeout, @default_timeout_ms), fn ->
      started_at = System.monotonic_time(:millisecond)
      result = call(:fprof, :apply, [fun, []])
      call(:fprof, :profile, [])
      analysis = capture_io(fn -> call(:fprof, :analyse, [[dest: []]]) end)
      call(:fprof, :stop, [])

      profile_result(:fprof, started_at, result, analysis)
    end)
  end

  defp monitored_profile(profiler, timeout, run) do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn -> send(parent, {:vibe_profile, self(), run.()}) end)

    receive do
      {:vibe_profile, ^pid, result} ->
        Process.demonitor(ref, [:flush])
        result

      {:DOWN, ^ref, :process, ^pid, reason} ->
        %{profiler: profiler, error: Exception.format_exit(reason)}
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :brutal_kill)
        %{profiler: profiler, error: "timed out after #{timeout}ms"}
    end
  end

  defp profile_result(profiler, started_at, result, analysis) do
    %{
      profiler: profiler,
      duration_ms: System.monotonic_time(:millisecond) - started_at,
      result: safe_inspect(result),
      analysis: analysis
    }
  end

  @spec process_growth(non_neg_integer(), keyword()) :: [map()]
  def process_growth(duration_ms \\ @default_growth_duration_ms, opts \\ []) do
    limit = Keyword.get(opts, :limit, 15)
    before = process_metrics()
    Process.sleep(duration_ms)
    after_ = process_metrics()

    after_
    |> Enum.flat_map(fn {pid, metrics} ->
      case before[pid] do
        nil ->
          []

        old ->
          [
            Map.merge(metrics, %{
              pid: inspect(pid),
              memory_delta: metrics.memory - old.memory,
              reductions_delta: metrics.reductions - old.reductions,
              queue_delta: metrics.message_queue_len - old.message_queue_len
            })
          ]
      end
    end)
    |> Enum.sort_by(&(&1.memory_delta + &1.reductions_delta), :desc)
    |> Enum.take(limit)
  end

  defp collect_cprof(:all, limit) do
    call(:cprof, :analyse, [])
    |> Enum.flat_map(fn {module, calls, functions} ->
      Enum.map(functions, fn {{function, arity}, count} ->
        %{mfa: {module, function, arity}, calls: count, module_calls: calls}
      end)
    end)
    |> Enum.sort_by(& &1.calls, :desc)
    |> Enum.take(limit)
  end

  defp collect_cprof(modules, limit) when is_list(modules) do
    modules
    |> Enum.flat_map(fn module ->
      case call(:cprof, :analyse, [module]) do
        {^module, calls, functions} ->
          Enum.map(functions, fn {{function, arity}, count} ->
            %{mfa: {module, function, arity}, calls: count, module_calls: calls}
          end)

        _ ->
          []
      end
    end)
    |> Enum.sort_by(& &1.calls, :desc)
    |> Enum.take(limit)
  end

  defp process_metrics do
    Map.new(Process.list(), fn pid ->
      info = Process.info(pid, [:memory, :reductions, :message_queue_len]) || []

      {pid,
       %{
         memory: info[:memory] || 0,
         reductions: info[:reductions] || 0,
         message_queue_len: info[:message_queue_len] || 0
       }}
    end)
  end

  defp capture_io(fun) do
    {:ok, io} = StringIO.open("")
    original_gl = Process.group_leader()
    Process.group_leader(self(), io)

    try do
      fun.()
      {_, content} = StringIO.contents(io)
      content
    after
      Process.group_leader(self(), original_gl)
      StringIO.close(io)
    end
  end

  defp call(module, function, args), do: apply(module, function, args)

  defp safe_inspect(term),
    do: inspect(term, charlists: :as_lists, limit: 20, printable_limit: 500)
end
