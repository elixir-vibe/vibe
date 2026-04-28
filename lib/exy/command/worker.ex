defmodule Exy.Command.Worker do
  @moduledoc false

  use GenServer

  alias Exy.Command.{Job, Result}

  @max_memory_output_bytes 65_536

  defstruct [
    :id,
    :argv,
    :cwd,
    :env,
    :port,
    :output_path,
    :started_mono,
    :started_at,
    :exit_status,
    :status,
    :on_output,
    awaiters: [],
    output: ""
  ]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @spec job(pid()) :: Job.t()
  def job(pid), do: GenServer.call(pid, :job)

  @spec await(pid(), timeout()) :: Result.t()
  def await(pid, timeout), do: GenServer.call(pid, :await, timeout)

  @spec status(pid()) :: Result.t()
  def status(pid), do: GenServer.call(pid, :status)

  @spec output(pid(), keyword()) :: String.t()
  def output(pid, opts \\ []), do: GenServer.call(pid, {:output, opts})

  @spec cancel(pid()) :: Result.t()
  def cancel(pid), do: GenServer.call(pid, :cancel)

  @impl true
  def init(opts) do
    argv = opts |> Keyword.fetch!(:argv) |> normalize_argv()
    cwd = opts |> Keyword.get(:cd, File.cwd!()) |> expand_path()
    env = opts |> Keyword.get(:env, []) |> Exy.Env.to_charlist_pairs()
    id = Keyword.get_lazy(opts, :id, &new_id/0)
    output_path = Keyword.get_lazy(opts, :output_path, fn -> default_output_path(id) end)
    on_output = Keyword.get(opts, :on_output)
    File.mkdir_p!(Path.dirname(output_path))
    File.write!(output_path, "")

    port =
      Port.open({:spawn_executable, executable(argv)}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: args(argv),
        cd: cwd,
        env: env
      ])

    {:ok,
     %__MODULE__{
       id: id,
       argv: argv,
       cwd: cwd,
       env: env,
       port: port,
       output_path: output_path,
       on_output: on_output,
       started_mono: System.monotonic_time(:millisecond),
       started_at: DateTime.utc_now(),
       status: :running
     }}
  end

  @impl true
  def handle_call(:job, _from, state), do: {:reply, build_job(state), state}
  def handle_call(:status, _from, state), do: {:reply, result(state), state}

  def handle_call({:output, opts}, _from, state),
    do: {:reply, read_output(state.output_path, opts), state}

  def handle_call(:await, from, %{status: :running} = state) do
    {:noreply, Map.update(state, :awaiters, [from], &[from | List.wrap(&1)])}
  end

  def handle_call(:await, _from, state), do: {:reply, result(state), state}

  def handle_call(:cancel, _from, %{status: :running} = state) do
    Port.close(state.port)
    state = finish(%{state | status: :cancelled})
    {:reply, result(state), state}
  end

  def handle_call(:cancel, _from, state), do: {:reply, result(state), state}

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    File.write!(state.output_path, data, [:append])
    state = append_output(state, data)
    maybe_stream_output(state)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port, status: :running} = state) do
    state = finish(%{state | exit_status: status, status: if(status == 0, do: :ok, else: :error)})
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, _status}}, %{port: port} = state), do: {:noreply, state}

  def handle_info(_message, state), do: {:noreply, state}

  defp finish(state) do
    result = result(state)

    state
    |> Map.get(:awaiters, [])
    |> Enum.each(&GenServer.reply(&1, result))

    Map.put(state, :awaiters, [])
  end

  defp build_job(state) do
    %Job{
      id: state.id,
      argv: state.argv,
      cwd: state.cwd,
      pid: self(),
      output_path: state.output_path,
      started_at: state.started_at
    }
  end

  defp result(state) do
    %Result{
      id: state.id,
      argv: state.argv,
      cwd: state.cwd,
      status: state.status,
      exit_status: state.exit_status,
      output: state.output,
      output_path: state.output_path,
      duration_ms: max(System.monotonic_time(:millisecond) - state.started_mono, 0)
    }
  end

  defp append_output(state, data) do
    output = state.output <> data

    if byte_size(output) > @max_memory_output_bytes do
      %{
        state
        | output:
            binary_part(
              output,
              byte_size(output) - @max_memory_output_bytes,
              @max_memory_output_bytes
            )
      }
    else
      %{state | output: output}
    end
  end

  defp maybe_stream_output(%{on_output: callback, output: output}) when is_function(callback, 1),
    do: callback.(output)

  defp maybe_stream_output(_state), do: :ok

  defp read_output(path, opts) do
    output = File.read!(path)

    case Keyword.get(opts, :tail) do
      tail when is_integer(tail) and tail > 0 ->
        output |> String.split("\n") |> Enum.take(-tail) |> Enum.join("\n")

      _tail ->
        output
    end
  end

  defp normalize_argv(argv) when is_list(argv), do: Enum.map(argv, &to_string/1)
  defp executable([executable | _args]), do: System.find_executable(executable) || executable
  defp args([_executable | args]), do: args

  defp expand_path(path) do
    path
    |> to_string()
    |> Path.expand()
  end

  defp default_output_path(id), do: Path.join([Exy.Paths.home(), "commands", id <> ".log"])
  defp new_id, do: "cmd-" <> Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)
end
