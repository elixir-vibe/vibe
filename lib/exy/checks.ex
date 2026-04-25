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
  def run(:format, opts), do: format_check(opts)
  def run(:compile, opts), do: mix_check(:compile, "compile", ["--warnings-as-errors"], opts)
  def run(:test, opts), do: mix_check(:test, "test", Keyword.get(opts, :test_args, []), opts)
  def run(:credo, opts), do: credo_check(opts)
  def run(:ex_slop, opts), do: ex_slop_check(opts)

  def run(:dialyzer, opts),
    do: mix_check(:dialyzer, "dialyzer", Keyword.get(opts, :dialyzer_args, []), opts)

  def run(:ex_dna, opts), do: ex_dna_check(opts)

  def run(:reach, opts) do
    case ensure_optional_app(:reach) do
      :ok -> reach_check(opts)
      {:error, reason} -> %{name: :reach, status: :error, details: reason}
    end
  end

  def run(name, _opts), do: %{name: name, status: :error, details: {:unknown_check, name}}

  @spec ok?(keyword()) :: boolean()
  def ok?(opts \\ []), do: match?({:ok, _}, run_all(opts))

  defp format_check(opts) do
    paths = Keyword.get(opts, :format_paths, ["*.exs", "{config,lib,test}/**/*.{ex,exs}"])

    stale =
      paths
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.reject(&formatted?/1)

    status = if stale == [], do: :ok, else: :error
    %{name: :format, status: status, details: %{stale: stale}}
  end

  defp formatted?(path) do
    source = File.read!(path)

    {formatter, _opts} = Mix.Tasks.Format.formatter_for_file(path)
    formatted = source |> formatter.() |> IO.iodata_to_binary()

    source == formatted
  end

  defp credo_check(opts) do
    case ensure_optional_app(:credo) do
      :ok -> run_credo(opts)
      {:error, reason} -> %{name: :credo, status: :error, details: reason}
    end
  end

  defp reach_check(opts) do
    paths = Keyword.get(opts, :paths, ["lib/**/*.ex"])
    files = paths |> Enum.flat_map(&Path.wildcard/1) |> Enum.sort()

    errors =
      Enum.flat_map(files, fn file ->
        case reach_file_to_graph(file) do
          {:ok, graph} ->
            if graph_node_count(graph) > 0, do: [], else: [%{file: file, reason: :empty_graph}]

          {:error, reason} ->
            [%{file: file, reason: reason}]
        end
      end)

    status = if errors == [], do: :ok, else: :error
    %{name: :reach, status: status, details: %{files: length(files), errors: errors}}
  end

  defp run_credo(opts) do
    argv = opts |> Keyword.get(:credo_args, ["--strict"]) |> add_mute_exit_status()
    {output, exec} = capture_io(fn -> eval_optional("Credo.run(argv)", argv: argv) end)
    issues = eval_optional("Credo.Execution.get_issues(exec)", exec: exec)
    status = if issues == [], do: :ok, else: :error

    %{
      name: :credo,
      status: status,
      details: %{issues: Enum.map(issues, &issue_to_map/1), output: output}
    }
  end

  defp graph_node_count(graph), do: graph |> reach_nodes() |> length()

  defp reach_file_to_graph(file), do: eval_optional("Reach.file_to_graph(file)", file: file)

  defp reach_nodes(graph), do: eval_optional("Reach.nodes(graph)", graph: graph)

  defp ex_slop_check(opts) do
    case ensure_optional_app(:credo) do
      :ok -> run_ex_slop(opts)
      {:error, reason} -> %{name: :ex_slop, status: :error, details: reason}
    end
  end

  defp ex_dna_check(opts) do
    case ensure_optional_app(:ex_dna) do
      :ok -> run_ex_dna(opts)
      {:error, reason} -> %{name: :ex_dna, status: :error, details: reason}
    end
  end

  defp run_ex_slop(opts) do
    paths = Keyword.get(opts, :paths, ["lib", "test"])

    issues =
      paths
      |> source_files()
      |> Enum.flat_map(fn source_file ->
        ex_slop_checks()
        |> Enum.flat_map(fn check -> check.run(source_file, []) |> List.wrap() end)
      end)

    status = if issues == [], do: :ok, else: :error
    %{name: :ex_slop, status: status, details: %{issues: Enum.map(issues, &issue_to_map/1)}}
  end

  defp run_ex_dna(opts) do
    paths = Keyword.get(opts, :paths, ["lib", "test"])
    report = eval_optional("ExDNA.analyze(paths: paths, reporters: [])", paths: paths)
    clones = Map.get(report, :clones, [])
    status = if clones == [], do: :ok, else: :error
    %{name: :ex_dna, status: status, details: %{stats: Map.get(report, :stats), clones: clones}}
  end

  defp ex_slop_checks do
    config = credo_config()
    checks = get_in(config, [:checks, :extra]) || []
    disabled = config |> get_in([:checks, :disabled]) |> List.wrap() |> Enum.map(&check_module/1)

    checks
    |> Enum.map(&check_module/1)
    |> Enum.filter(&match?(<<"Elixir.ExSlop.", _::binary>>, Atom.to_string(&1)))
    |> Enum.reject(&(&1 in disabled))
  end

  defp credo_config do
    case Code.eval_file(".credo.exs") do
      {%{configs: [config | _]}, _binding} -> config
      {_config, _binding} -> %{}
    end
  end

  defp check_module({module, _opts}), do: module
  defp check_module(module), do: module

  defp summarize_result(%{name: name, status: status, details: details}) do
    %{name: name, status: status, count: detail_count(details)}
  end

  defp failure_report(%{name: name, details: details}) do
    %{name: name, details: compact_details(details)}
  end

  defp detail_count(%{issues: issues}) when is_list(issues), do: length(issues)
  defp detail_count(%{clones: clones}) when is_list(clones), do: length(clones)
  defp detail_count(%{stale: stale}) when is_list(stale), do: length(stale)
  defp detail_count(%{output: output}) when is_binary(output), do: byte_size(output)
  defp detail_count(_details), do: nil

  defp compact_details(%{output: output} = details) when is_binary(output) do
    %{details | output: String.slice(output, 0, 8_000)}
  end

  defp compact_details(%{issues: issues} = details) when is_list(issues),
    do: %{details | issues: Enum.take(issues, 20)}

  defp compact_details(%{clones: clones} = details) when is_list(clones),
    do: %{details | clones: Enum.take(clones, 10)}

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
    |> Enum.map(fn path ->
      eval_optional("Credo.SourceFile.parse(source, path)", source: File.read!(path), path: path)
    end)
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

  defp eval_optional(code, binding) do
    {result, _binding} = Code.eval_string(code, binding)
    result
  end

  defp ensure_optional_app(app) do
    case Application.ensure_all_started(app) do
      {:ok, _apps} -> :ok
      {:error, reason} -> {:error, {:optional_dependency_unavailable, app, reason}}
    end
  end

  defp add_mute_exit_status(argv) do
    if "--mute-exit-status" in argv, do: argv, else: ["--mute-exit-status" | argv]
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
