defmodule Exy.Subagents.Manager do
  @moduledoc false

  use GenServer

  alias Exy.Subagents.{JobBuilder, JobInfo}

  defstruct jobs: %{}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec start_job(String.t(), keyword()) :: {:ok, JobInfo.t()} | {:error, term()}
  def start_job(task, opts \\ []), do: GenServer.call(__MODULE__, {:start_job, task, opts})

  @spec jobs() :: [JobInfo.t()]
  def jobs, do: GenServer.call(__MODULE__, :jobs)

  @spec status(String.t()) :: {:ok, JobInfo.t()} | {:error, :not_found}
  def status(id), do: GenServer.call(__MODULE__, {:status, id})

  @spec result(String.t()) :: {:ok, term()} | {:error, term()}
  def result(id), do: GenServer.call(__MODULE__, {:result, id})

  @spec cancel(String.t()) :: :ok | {:error, :not_found}
  def cancel(id), do: GenServer.call(__MODULE__, {:cancel, id})

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{jobs: JobBuilder.reconstruct()}}

  @impl true
  def handle_call({:start_job, task, opts}, _from, state) do
    case JobBuilder.new(task, opts) do
      {:ok, job} ->
        start_job_child(job, opts, state)

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:jobs, _from, state), do: {:reply, Map.values(state.jobs), state}

  def handle_call({:status, id}, _from, state) do
    case Map.fetch(state.jobs, id) do
      {:ok, job} -> {:reply, {:ok, job}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:result, id}, _from, state) do
    case Map.fetch(state.jobs, id) do
      {:ok, %{status: :ok, result: result}} -> {:reply, {:ok, result}, state}
      {:ok, %{status: :error, error: error}} -> {:reply, {:error, error}, state}
      {:ok, %{status: status}} -> {:reply, {:error, status}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:cancel, id}, _from, state) do
    case Map.fetch(state.jobs, id) do
      {:ok, %{pid: pid}} when is_pid(pid) ->
        Exy.Subagents.Job.cancel(pid)
        {:reply, :ok, state}

      {:ok, _job} ->
        {:reply, :ok, state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_cast({:job_finished, %JobInfo{} = job}, state) do
    {:noreply, put_in(state.jobs[job.id], job)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {id, job} = Enum.find(state.jobs, {nil, nil}, fn {_id, job} -> job.pid == pid end)

    state =
      if id && job && job.status == :running do
        job = %{
          job
          | status: :error,
            error: Exception.format_exit(reason),
            finished_at: DateTime.utc_now()
        }

        put_in(state.jobs[id], job)
      else
        state
      end

    {:noreply, state}
  end

  defp start_job_child(job, opts, state) do
    child_spec = %{
      id: {Exy.Subagents.Job, job.id},
      start: {Exy.Subagents.Job, :start_link, [job, opts]},
      restart: :temporary
    }

    case DynamicSupervisor.start_child(Exy.Subagents.JobSupervisor, child_spec) do
      {:ok, pid} ->
        job = %{job | pid: pid}
        Process.monitor(pid)
        {:reply, {:ok, job}, put_in(state.jobs[job.id], job)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end
