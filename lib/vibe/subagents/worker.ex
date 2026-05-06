defmodule Vibe.Subagents.Worker do
  @moduledoc "Supervised worker process for individual subagent tasks."
  use GenServer

  def start_link(spec, parent, budget) do
    GenServer.start_link(__MODULE__, {spec, parent, budget}, name: via(spec.id))
  end

  @impl true
  def init({spec, parent, budget}) do
    meta = [
      role: Map.get(spec, :role, :worker),
      goal: Map.get(spec, :goal),
      started_at: System.system_time(:millisecond)
    ]

    Registry.register(Vibe.Registry, {:subagent, spec.id}, meta)
    send(self(), :run)

    {:ok,
     %{
       spec: spec,
       parent: parent,
       budget: budget,
       started_at: System.monotonic_time(:millisecond)
     }}
  end

  @impl true
  def handle_info(:run, state) do
    result = execute(state)
    send(state.parent, {:vibe_subagent_result, state.spec.id, result})
    {:stop, :normal, state}
  end

  defp execute(%{spec: spec, budget: budget, started_at: started_at}) do
    Vibe.Session.Store.append_trajectory(:subagent_started, %{
      id: spec.id,
      role: Map.get(spec, :role),
      goal: spec.goal
    })

    status =
      try do
        if Vibe.Budget.allowed?(budget) do
          {:ok, spec.run.(spec)}
        else
          {:error, :budget_exhausted}
        end
      rescue
        exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
      catch
        kind, reason -> {:error, Exception.format(kind, reason, __STACKTRACE__)}
      end

    result =
      case status do
        {:ok, value} ->
          %{
            id: spec.id,
            role: Map.get(spec, :role, :worker),
            goal: spec.goal,
            status: :ok,
            result: value,
            duration_ms: elapsed(started_at)
          }

        {:error, reason} ->
          %{
            id: spec.id,
            role: Map.get(spec, :role, :worker),
            goal: spec.goal,
            status: :error,
            error: reason,
            duration_ms: elapsed(started_at)
          }
      end

    Vibe.Session.Store.append_trajectory(:subagent_finished, result)
    result
  end

  defp elapsed(started_at), do: System.monotonic_time(:millisecond) - started_at

  defp via(id), do: {:via, Registry, {Vibe.Registry, {:subagent_worker, id}}}
end
