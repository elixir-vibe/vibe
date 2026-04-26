defmodule Exy.Subagents.Job do
  @moduledoc false

  use GenServer

  alias Exy.Session
  alias Exy.Subagents.JobInfo
  alias Exy.UI.Event

  @spec start_link(JobInfo.t(), keyword()) :: GenServer.on_start()
  def start_link(%JobInfo{} = job, opts) do
    GenServer.start_link(__MODULE__, {job, opts}, name: via(job.id))
  end

  @spec cancel(pid()) :: :ok
  def cancel(pid), do: GenServer.cast(pid, :cancel)

  @impl true
  def init({job, opts}) do
    Registry.register(Exy.Registry, {:subagent, job.id}, registry_meta(job))
    send(self(), :run)

    {:ok,
     %{
       job: job,
       opts: opts,
       session: nil,
       timeout_ref: nil,
       started_at: System.monotonic_time(:millisecond)
     }}
  end

  @impl true
  def handle_info(:run, state) do
    {:ok, session} = start_child_session(state.job, state.opts)
    {:ok, _snapshot, _cursor} = Session.attach(session, self())

    Exy.Session.Store.append_trajectory(:subagent_started, trajectory_start(state.job),
      session_id: state.job.parent_session_id || state.job.child_session_id
    )

    :ok = Session.lock(session, state.job.id, self())
    emit_parent_event(state.job, :subagent_started, trajectory_start(state.job))
    :ok = Session.dispatch(session, {:submit_prompt, %{text: state.job.task}})
    timeout_ref = Process.send_after(self(), :timeout, Keyword.get(state.opts, :timeout, 120_000))
    {:noreply, %{state | session: session, timeout_ref: timeout_ref}}
  end

  def handle_info(
        {Exy.Session, :event, %Event{type: :assistant_message_added, data: data}},
        state
      ) do
    finish(state, {:ok, Map.get(data, :result) || Map.get(data, :text) || inspect(data)})
  end

  def handle_info({Exy.Session, :event, %Event{type: :assistant_stream_finished}}, state) do
    finish(state, {:ok, final_assistant_text(state.session)})
  end

  def handle_info({Exy.Session, :event, %Event{type: :assistant_aborted, data: data}}, state) do
    finish(state, {:error, Map.get(data, :reason, "aborted")})
  end

  def handle_info({Exy.Session, :event, _event}, state), do: {:noreply, state}

  def handle_info(:timeout, state) do
    if state.session do
      Session.dispatch(state.session, :cancel_stream)
    end

    finish(state, {:error, :timeout})
  end

  @impl true
  def handle_cast(:cancel, state) do
    if state.session do
      Session.dispatch(state.session, :cancel_stream)
    end

    finish(state, {:error, :cancelled})
  end

  defp start_child_session(job, opts) do
    session_opts = [
      session_id: job.child_session_id,
      model: job.model,
      role: job.role,
      system: Exy.Agent.Profile.system_for(profile_opts(job, opts)),
      allowed_tools: Exy.Agent.Profile.tools_for(profile_opts(job, opts)),
      ask_fun: Keyword.get(opts, :ask_fun, &Exy.UI.PromptRunner.default_ask/2)
    ]

    Session.start(session_opts)
  end

  defp profile_opts(job, opts), do: Keyword.put_new(opts, :role, job.role)

  defp finish(state, result) do
    if state.timeout_ref, do: Process.cancel_timer(state.timeout_ref)

    job = finish_job(state.job, result, state.started_at)

    if state.session, do: Session.unlock(state.session, job.id)

    Exy.Session.Store.append_trajectory(:subagent_finished, Map.from_struct(job),
      session_id: job.parent_session_id || job.child_session_id
    )

    emit_parent_event(job, :subagent_finished, Map.from_struct(job))

    if job.parent_session_id do
      Exy.Memory.Manager.on_delegation(job.task, result_text(job), %{
        parent_session_id: job.parent_session_id,
        child_session_id: job.child_session_id,
        job_id: job.id
      })
    end

    GenServer.cast(Exy.Subagents.Manager, {:job_finished, job})
    {:stop, :normal, %{state | job: job}}
  end

  defp finish_job(job, {:ok, result}, started_at) do
    %{
      job
      | status: :ok,
        result: result,
        finished_at: DateTime.utc_now(),
        duration_ms: System.monotonic_time(:millisecond) - started_at
    }
  end

  defp finish_job(job, {:error, error}, started_at) do
    %{
      job
      | status: :error,
        error: inspect(error),
        finished_at: DateTime.utc_now(),
        duration_ms: System.monotonic_time(:millisecond) - started_at
    }
  end

  defp final_assistant_text(session) do
    session
    |> Session.state()
    |> Map.get(:messages)
    |> Enum.reverse()
    |> Enum.find_value("", fn
      %{role: :assistant, text: text} when is_binary(text) -> text
      %{role: :assistant, result: result} -> result_text(result)
      _message -> nil
    end)
  end

  defp result_text(%{output: output}) when is_binary(output), do: output
  defp result_text(value) when is_binary(value), do: value
  defp result_text(value), do: inspect(value)

  defp emit_parent_event(%{parent_session_id: nil}, _type, _data), do: :ok

  defp emit_parent_event(job, type, data) do
    with {:ok, parent} <- Session.lookup(job.parent_session_id) do
      Session.emit_event(parent, Event.new(type, job.parent_session_id, data))
    end
  end

  defp trajectory_start(job) do
    %{
      id: job.id,
      role: job.role,
      task: job.task,
      child_session_id: job.child_session_id,
      parent_session_id: job.parent_session_id,
      model: job.model
    }
  end

  defp registry_meta(job) do
    [
      role: job.role,
      task: job.task,
      child_session_id: job.child_session_id,
      parent_session_id: job.parent_session_id,
      model: job.model,
      started_at: System.system_time(:millisecond)
    ]
  end

  defp via(id), do: {:via, Registry, {Exy.Registry, {:subagent_worker, id}}}
end
