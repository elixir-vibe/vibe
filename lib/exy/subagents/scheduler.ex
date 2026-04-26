defmodule Exy.Subagents.Scheduler do
  @moduledoc false

  use GenServer

  alias Exy.Subagents.{Schedule, Store}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec schedule(String.t(), keyword()) :: {:ok, Schedule.t()} | {:error, term()}
  def schedule(task, opts \\ []), do: GenServer.call(__MODULE__, {:schedule, task, opts})

  @spec scheduled() :: [Schedule.t()]
  def scheduled, do: GenServer.call(__MODULE__, :scheduled)

  @spec unschedule(String.t()) :: :ok | {:error, :not_found}
  def unschedule(id), do: GenServer.call(__MODULE__, {:unschedule, id})

  @impl true
  def init(_opts) do
    schedules =
      Store.schedules()
      |> Enum.reject(&missed_skip?/1)
      |> Enum.map(&schedule_timer/1)
      |> Map.new(&{&1.id, &1})

    {:ok, schedules}
  end

  @impl true
  def handle_call({:schedule, task, opts}, _from, state) do
    schedule =
      %Schedule{
        id: Keyword.get_lazy(opts, :id, &new_id/0),
        task: task,
        role: Keyword.get(opts, :role),
        parent_session_id: Keyword.get(opts, :parent_session_id),
        at: Keyword.get(opts, :at),
        every_ms: Keyword.get(opts, :every),
        missed: Keyword.get(opts, :missed, :skip),
        opts: Keyword.drop(opts, [:id, :at, :every, :missed])
      }
      |> schedule_timer()

    with :ok <- Store.append_created(schedule) do
      {:reply, {:ok, schedule}, Map.put(state, schedule.id, schedule)}
    end
  end

  def handle_call(:scheduled, _from, state), do: {:reply, Map.values(state), state}

  def handle_call({:unschedule, id}, _from, state) do
    case Map.pop(state, id) do
      {nil, state} ->
        {:reply, {:error, :not_found}, state}

      {schedule, state} ->
        if schedule.timer_ref, do: Process.cancel_timer(schedule.timer_ref)
        _ = Store.append_cancelled(id)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:run_schedule, id}, state) do
    case Map.get(state, id) do
      nil ->
        {:noreply, state}

      schedule ->
        _ = Exy.Subagents.start(schedule.task, schedule.opts)
        state = reschedule(state, schedule)
        {:noreply, state}
    end
  end

  defp reschedule(state, %{every_ms: every_ms} = schedule)
       when is_integer(every_ms) and every_ms > 0 do
    schedule = schedule_timer(%{schedule | at: nil, timer_ref: nil})
    Map.put(state, schedule.id, schedule)
  end

  defp reschedule(state, schedule), do: Map.delete(state, schedule.id)

  defp missed_skip?(%{at: %DateTime{} = at, every_ms: every_ms, missed: :skip})
       when is_nil(every_ms) do
    DateTime.compare(at, DateTime.utc_now()) == :lt
  end

  defp missed_skip?(_schedule), do: false

  defp schedule_timer(%Schedule{} = schedule) do
    delay = delay(schedule)
    timer_ref = Process.send_after(self(), {:run_schedule, schedule.id}, delay)

    %{
      schedule
      | timer_ref: timer_ref,
        next_run_at: DateTime.add(DateTime.utc_now(), delay, :millisecond)
    }
  end

  defp delay(%{every_ms: every_ms}) when is_integer(every_ms) and every_ms > 0, do: every_ms

  defp delay(%{at: %DateTime{} = at}) do
    max(DateTime.diff(at, DateTime.utc_now(), :millisecond), 0)
  end

  defp delay(_schedule), do: 0

  defp new_id do
    "sch-" <> Base.url_encode64(:crypto.strong_rand_bytes(5), padding: false)
  end
end
