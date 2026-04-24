defmodule Exy.Checks do
  @moduledoc """
  Native validation gates Exy can run before and after self-modification.

  Prefer library APIs where available. Mix tasks are used only where the Elixir
  ecosystem exposes the check primarily as a Mix pipeline, and never through an
  external shell command.
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
    checks =
      Keyword.get(opts, :checks, [:format, :compile, :test, :credo, :ex_slop, :ex_dna, :reach])

    cwd = Keyword.get(opts, :cwd, File.cwd!())

    results = File.cd!(cwd, fn -> Enum.map(checks, &run(&1, opts)) end)

    if Enum.all?(results, &(&1.status == :ok)), do: {:ok, results}, else: {:error, results}
  end

  @spec run(atom()) :: check_result()
  def run(name), do: run(name, [])

  @spec run(atom(), keyword()) :: check_result()
  def run(:format, opts), do: mix_check(:format, "format", ["--check-formatted"], opts)
  def run(:compile, opts), do: mix_check(:compile, "compile", ["--warnings-as-errors"], opts)
  def run(:test, opts), do: exunit_check(opts)

  def run(:credo, opts) do
    argv = Keyword.get(opts, :credo_args, ["--mute-exit-status"])
    fail_categories = Keyword.get(opts, :credo_fail_categories, [:warning])

    with_available(:credo, fn ->
      {output, exec} = capture_io(fn -> Credo.run(argv) end)
      issues = Credo.Execution.get_issues(exec)
      blocking = Enum.filter(issues, &(&1.category in fail_categories))
      status = if blocking == [], do: :ok, else: :error

      %{
        name: :credo,
        status: status,
        details: %{
          issues: Enum.map(issues, &issue_to_map/1),
          blocking: Enum.map(blocking, &issue_to_map/1),
          output: output
        }
      }
    end)
  end

  def run(:ex_slop, opts) do
    paths = Keyword.get(opts, :paths, ["lib", "test"])

    with_available(:ex_slop, fn ->
      issues =
        paths
        |> source_files()
        |> Enum.flat_map(fn source_file ->
          Enum.flat_map(ExSlop.checks(), fn check ->
            check.run(source_file, []) |> List.wrap()
          end)
        end)

      status = if issues == [], do: :ok, else: :error
      %{name: :ex_slop, status: status, details: Enum.map(issues, &issue_to_map/1)}
    end)
  end

  def run(:ex_dna, opts) do
    paths = Keyword.get(opts, :paths, ["lib", "test"])

    with_available(:ex_dna, fn ->
      report = ExDNA.analyze(paths: paths, reporters: [])
      clones = Map.get(report, :clones, [])
      status = if clones == [], do: :ok, else: :error
      %{name: :ex_dna, status: status, details: %{stats: Map.get(report, :stats), clones: clones}}
    end)
  end

  def run(:reach, opts) do
    paths = Keyword.get(opts, :paths, ["lib/**/*.ex"])

    with_available(:reach, fn ->
      files = paths |> Enum.flat_map(&Path.wildcard/1) |> Enum.sort()
      project = Reach.Project.from_sources(files)

      %{
        name: :reach,
        status: :ok,
        details: %{files: length(files), nodes: map_size(project.nodes)}
      }
    end)
  end

  def run(name, _opts), do: %{name: name, status: :error, details: {:unknown_check, name}}

  @spec ok?(keyword()) :: boolean()
  def ok?(opts \\ []) do
    match?({:ok, _}, run_all(opts))
  end

  defp summarize_result(%{name: name, status: status, details: details}) do
    %{name: name, status: status, count: detail_count(details)}
  end

  defp failure_report(%{name: name, details: details}) do
    %{name: name, details: compact_details(details)}
  end

  defp detail_count(%{blocking: blocking}) when is_list(blocking), do: length(blocking)
  defp detail_count(%{clones: clones}) when is_list(clones), do: length(clones)
  defp detail_count(details) when is_list(details), do: length(details)
  defp detail_count(_details), do: nil

  defp compact_details(%{blocking: blocking}) when is_list(blocking), do: blocking
  defp compact_details(%{issues: issues}) when is_list(issues), do: Enum.take(issues, 20)

  defp compact_details(%{clones: clones, stats: stats}),
    do: %{stats: stats, clones: Enum.take(clones, 10)}

  defp compact_details(details) when is_list(details), do: Enum.take(details, 20)
  defp compact_details(details), do: details

  defp exunit_check(opts) do
    files = Keyword.get(opts, :test_files, Path.wildcard("test/**/*_test.exs"))

    try do
      ExUnit.start(autorun: false)
      Code.require_file("test/test_helper.exs")
      Enum.each(files, &Code.require_file/1)
      result = ExUnit.run()
      failures = result.failures + Map.get(result, :excluded, 0)
      status = if failures == 0, do: :ok, else: :error
      %{name: :test, status: status, details: result}
    rescue
      exception ->
        %{
          name: :test,
          status: :error,
          details: Exception.format(:error, exception, __STACKTRACE__)
        }
    catch
      :exit, reason -> %{name: :test, status: :error, details: reason}
    end
  end

  defp mix_check(name, task, args, _opts) do
    Mix.Task.clear()

    try do
      Mix.Task.run(task, args)
      %{name: name, status: :ok, details: :ok}
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

  defp with_available(app, fun) do
    case Application.ensure_all_started(app) do
      {:ok, _} -> fun.()
      {:error, {:already_started, _}} -> fun.()
      {:error, reason} -> %{name: app, status: :error, details: {:not_available, reason}}
    end
  rescue
    exception ->
      %{name: app, status: :error, details: Exception.format(:error, exception, __STACKTRACE__)}
  end

  defp source_files(paths) do
    paths
    |> Enum.flat_map(fn path ->
      cond do
        File.dir?(path) -> Path.wildcard(Path.join(path, "**/*.{ex,exs}"))
        String.contains?(path, "*") -> Path.wildcard(path)
        true -> [path]
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn path -> Credo.SourceFile.parse(File.read!(path), path) end)
  end

  defp issue_to_map(%{
         check: check,
         filename: filename,
         line_no: line,
         column: column,
         message: message
       }) do
    %{check: inspect(check), file: filename, line: line, column: column, message: message}
  end

  defp issue_to_map(issue), do: issue
end
