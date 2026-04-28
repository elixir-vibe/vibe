defmodule Exy.Script do
  @moduledoc """
  Run Livebook-style Elixir scripts, including `Mix.install/2`.

  By default scripts run in a disposable BEAM OS process. Use
  `runtime: :standalone` to evaluate through `Exy.Runtime.Standalone`, which keeps
  Livebook-like binding/env state in a child BEAM process.
  """

  alias Exy.Runtime.Standalone

  @default_timeout_ms 120_000

  @type result :: %{
          status: :ok | :error | :timeout,
          exit_status: non_neg_integer() | nil,
          output: String.t()
        }

  @spec run(Path.t(), keyword()) :: result()
  def run(path, opts \\ []) when is_binary(path) do
    case Keyword.get(opts, :runtime, :os_process) do
      :standalone -> run_in_standalone(path, opts)
      :os_process -> run_os_process(path, opts)
    end
  end

  @spec run_string(String.t(), keyword()) :: result()
  def run_string(source, opts \\ []) when is_binary(source) do
    tmp_dir = Path.join(System.tmp_dir!(), "exy-script-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    path = Path.join(tmp_dir, "script.exs")
    File.write!(path, source)

    try do
      run(path, opts)
    after
      File.rm_rf(tmp_dir)
    end
  end

  defp run_in_standalone(path, opts) do
    case Standalone.start_link(
           cwd: Keyword.get(opts, :cwd, File.cwd!()),
           env: Keyword.get(opts, :env, %{})
         ) do
      {:ok, runtime} ->
        try do
          source = File.read!(path)

          case Standalone.evaluate(runtime, source,
                 timeout: Keyword.get(opts, :timeout, @default_timeout_ms),
                 file: path
               ) do
            {:ok, result} ->
              %{
                status: result.status,
                exit_status: if(result.status == :ok, do: 0, else: 1),
                output: result.output <> inspect_value(result)
              }

            {:error, reason} ->
              %{status: :error, exit_status: nil, output: inspect(reason)}
          end
        after
          Standalone.stop(runtime)
        end

      {:error, reason} ->
        %{status: :error, exit_status: nil, output: inspect(reason)}
    end
  rescue
    exception -> %{status: :error, exit_status: nil, output: Exception.message(exception)}
  end

  defp run_os_process(path, opts) do
    executable = Keyword.get(opts, :elixir, System.find_executable("elixir") || "elixir")
    args = Exy.Support.Lists.append(Keyword.get(opts, :args, []), path)
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    env = Keyword.get(opts, :env, [])
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    run_port(executable, args, cwd: cwd, env: env, timeout: timeout)
  end

  defp run_port(executable, args, opts) do
    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: args,
        cd: Keyword.fetch!(opts, :cwd),
        env: Exy.Env.to_charlist_pairs(Keyword.fetch!(opts, :env))
      ])

    collect(port, Keyword.fetch!(opts, :timeout), [])
  rescue
    exception -> %{status: :error, exit_status: nil, output: Exception.message(exception)}
  end

  defp collect(port, timeout, chunks) do
    receive do
      {^port, {:data, data}} ->
        collect(port, timeout, [data | chunks])

      {^port, {:exit_status, status}} ->
        %{
          status: if(status == 0, do: :ok, else: :error),
          exit_status: status,
          output: output(chunks)
        }
    after
      timeout ->
        Port.close(port)
        %{status: :timeout, exit_status: nil, output: output(chunks)}
    end
  end

  defp output(chunks), do: chunks |> Enum.reverse() |> IO.iodata_to_binary()

  defp inspect_value(%{status: :ok, value: nil}), do: ""
  defp inspect_value(%{status: :ok, value: value}), do: inspect(value, pretty: true) <> "\n"
  defp inspect_value(%{value: value}), do: to_string(value)
end
