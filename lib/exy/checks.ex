defmodule Exy.Checks do
  @moduledoc """
  Validation gates Exy can run before and after self-modification.
  """

  @type check_result :: %{name: atom(), status: :ok | :error, details: term()}

  @spec analyze(keyword()) :: map()
  def analyze(opts \\ []) do
    {status, results} = run_all(opts)
    failed = Enum.filter(results, &(&1.status == :error))

    %{
      status: status,
      ok?: status == :ok,
      passed: Enum.map(results -- failed, & &1.name),
      failed: Enum.map(failed, & &1.name),
      summary: Enum.map(results, &summarize_result/1),
      failures: Enum.map(failed, &failure_report/1),
      results: results
    }
  end

  @spec run_all(keyword()) :: {:ok, [check_result()]} | {:error, [check_result()]}
  def run_all(opts \\ []) do
    checks = Keyword.get(opts, :checks, [:format, :compile, :test, :credo, :dialyzer, :ex_dna])
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    results = File.cd!(cwd, fn -> Enum.map(checks, &run(&1, opts)) end)

    if Enum.all?(results, &(&1.status == :ok)), do: {:ok, results}, else: {:error, results}
  end

  @spec run(atom()) :: check_result()
  def run(name), do: run(name, [])

  @spec run(atom(), keyword()) :: check_result()
  def run(:format, opts), do: mix_check(:format, "format", ["--check-formatted"], opts)
  def run(:compile, opts), do: mix_check(:compile, "compile", ["--warnings-as-errors"], opts)
  def run(:test, opts), do: mix_check(:test, "test", Keyword.get(opts, :test_args, []), opts)

  def run(:credo, opts),
    do: mix_check(:credo, "credo", Keyword.get(opts, :credo_args, ["--strict"]), opts)

  def run(:ex_slop, opts), do: run(:credo, opts)

  def run(:dialyzer, opts),
    do: mix_check(:dialyzer, "dialyzer", Keyword.get(opts, :dialyzer_args, []), opts)

  def run(:ex_dna, opts),
    do: mix_check(:ex_dna, "ex_dna", Keyword.get(opts, :ex_dna_args, []), opts)

  def run(:reach, opts) do
    paths = Keyword.get(opts, :paths, ["lib/**/*.ex"])
    files = paths |> Enum.flat_map(&Path.wildcard/1) |> Enum.sort()
    %{name: :reach, status: :ok, details: %{files: length(files)}}
  end

  def run(name, _opts), do: %{name: name, status: :error, details: {:unknown_check, name}}

  @spec ok?(keyword()) :: boolean()
  def ok?(opts \\ []), do: match?({:ok, _}, run_all(opts))

  defp summarize_result(%{name: name, status: status, details: details}) do
    %{name: name, status: status, count: detail_count(details)}
  end

  defp failure_report(%{name: name, details: details}) do
    %{name: name, details: compact_details(details)}
  end

  defp detail_count(%{exit: 0}), do: 0
  defp detail_count(%{output: output}) when is_binary(output), do: byte_size(output)
  defp detail_count(_details), do: nil

  defp compact_details(%{output: output} = details) when is_binary(output) do
    %{details | output: String.slice(output, 0, 8_000)}
  end

  defp compact_details(details), do: details

  defp mix_check(name, task, args, _opts) do
    Mix.Task.clear()

    try do
      {_output, result} = capture_io(fn -> Mix.Task.run(task, args) end)
      %{name: name, status: :ok, details: %{result: result}}
    rescue
      exception ->
        %{
          name: name,
          status: :error,
          details: Exception.format(:error, exception, __STACKTRACE__)
        }
    catch
      :exit, reason -> %{name: name, status: :error, details: reason}
    end
  end

  defp capture_io(fun) do
    old_gl = Process.group_leader()
    old_shell = Mix.shell()
    {:ok, io} = StringIO.open("")

    try do
      Process.group_leader(self(), io)
      Mix.shell(Mix.Shell.Process)
      result = fun.()
      {_input, output} = StringIO.contents(io)
      {output <> shell_output(), result}
    after
      Mix.shell(old_shell)
      Process.group_leader(self(), old_gl)
    end
  end

  defp shell_output(acc \\ []) do
    receive do
      {:mix_shell, _kind, messages} -> shell_output([Enum.join(messages, " ") | acc])
    after
      0 -> acc |> Enum.reverse() |> Enum.join("\n")
    end
  end
end
