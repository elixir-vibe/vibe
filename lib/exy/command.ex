defmodule Exy.Command do
  @moduledoc """
  Supervised OS command execution for eval sessions and agents.

  Use `run/2` for the common synchronous case and `start/2` when a command should
  keep running in the background while its output remains inspectable.
  """

  alias Exy.Command.{Job, Result, Worker}

  @default_timeout 120_000

  @spec run([String.Chars.t()], keyword()) :: Result.t() | {:error, term()}
  def run(argv, opts \\ []) when is_list(argv) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    opts = Keyword.put_new_lazy(opts, :on_output, &Exy.Command.Streaming.callback_from_process/0)

    with {:ok, %Job{} = job} <- start(argv, opts) do
      await(job, timeout)
    end
  end

  @spec start([String.Chars.t()], keyword()) :: {:ok, Job.t()} | {:error, term()}
  def start(argv, opts \\ []) when is_list(argv) do
    child_spec = %{
      id: {Worker, System.unique_integer([:positive])},
      start: {Worker, :start_link, [Keyword.merge(opts, argv: argv)]},
      restart: :temporary
    }

    with {:ok, pid} <- DynamicSupervisor.start_child(Exy.Command.Supervisor, child_spec) do
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
