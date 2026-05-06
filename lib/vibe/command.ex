defmodule Vibe.Command do
  @moduledoc """
  Supervised OS command execution for eval sessions and agents.

  Commands run under Vibe's command supervisor instead of as untracked shell
  calls. Use `run/2` for bounded synchronous commands and `start/2` for long
  running jobs whose status, output, and cancellation should remain inspectable.

  Eval sessions alias this module as `Cmd`. Prefer `Cmd.run/2` and `Cmd.start/2`
  over raw `System.cmd/3` so command output can stream into the UI and cleanup is
  tied to Vibe's supervised runtime.
  """

  alias Vibe.Command.{Job, Result, Worker}

  @default_timeout 120_000

  @spec run([String.Chars.t()], keyword()) :: Result.t() | {:error, term()}
  def run(argv, opts \\ []) when is_list(argv) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    opts =
      opts
      |> Keyword.put_new_lazy(:on_output, &Vibe.Command.Streaming.callback_from_process/0)
      |> Keyword.put_new_lazy(:eval_session_id, &Vibe.Command.Streaming.current_session_id/0)

    with {:ok, %Job{} = job} <- start(argv, opts) do
      await(job, timeout)
    end
  end

  @spec start([String.Chars.t()], keyword()) :: {:ok, Job.t()} | {:error, term()}
  def start(argv, opts \\ []) when is_list(argv) do
    opts =
      Keyword.put_new_lazy(opts, :eval_session_id, &Vibe.Command.Streaming.current_session_id/0)

    child_spec = %{
      id: {Worker, System.unique_integer([:positive])},
      start: {Worker, :start_link, [Keyword.merge(opts, argv: argv)]},
      restart: :temporary
    }

    with {:ok, pid} <- DynamicSupervisor.start_child(Vibe.Command.Supervisor, child_spec) do
      Vibe.Command.Streaming.track(Keyword.get(opts, :eval_session_id), pid)
      {:ok, Worker.job(pid)}
    end
  end

  @spec await(Job.t() | pid(), timeout()) :: Result.t() | {:error, term()}
  def await(%Job{pid: pid}, timeout), do: await(pid, timeout)

  def await(pid, timeout) when is_pid(pid) do
    Worker.await(pid, timeout)
  catch
    :exit, {:timeout, _call} ->
      if Process.alive?(pid), do: Worker.cancel(pid), else: {:error, :command_unavailable}

    :exit, reason ->
      {:error, reason}
  end

  @spec status(Job.t() | pid()) :: Result.t() | {:error, term()}
  def status(%Job{pid: pid}), do: status(pid)

  def status(pid) when is_pid(pid) do
    Worker.status(pid)
  catch
    :exit, reason -> {:error, reason}
  end

  @spec output(Job.t() | pid(), keyword()) :: String.t() | {:error, term()}
  def output(job_or_pid, opts \\ [])
  def output(%Job{pid: pid}, opts), do: output(pid, opts)

  def output(pid, opts) when is_pid(pid) do
    Worker.output(pid, opts)
  catch
    :exit, reason -> {:error, reason}
  end

  @spec cancel(Job.t() | pid()) :: Result.t() | {:error, term()}
  def cancel(%Job{pid: pid}), do: cancel(pid)

  def cancel(pid) when is_pid(pid) do
    Worker.cancel(pid)
  catch
    :exit, reason -> {:error, reason}
  end
end
