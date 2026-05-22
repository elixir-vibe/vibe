defmodule Vibe.Code.Checks do
  @moduledoc """
  Validation gates Vibe can run before and after self-modification.
  """

  @max_failure_output_chars 8_000
  @max_issue_details 20
  @max_clone_details 10

  defmodule Result do
    @moduledoc false
    defstruct [:name, :status, :details, :count]
  end

  @type check_result :: %Result{name: atom(), status: :ok | :error, details: term()}

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
  def run(:ast_patterns, opts), do: ast_patterns_check(opts)
  def run(:ex_slop, opts), do: ex_slop_check(opts)

  def run(:dialyzer, opts),
    do: mix_check(:dialyzer, "dialyzer", Keyword.get(opts, :dialyzer_args, []), opts)

  def run(:ex_dna, opts), do: ex_dna_check(opts)

  def run(:reach, opts) do
    case ensure_optional_app(:reach) do
      :ok -> reach_check(opts)
      {:error, reason} -> %Result{name: :reach, status: :error, details: reason}
    end
  end

  def run(name, _opts), do: %Result{name: name, status: :error, details: {:unknown_check, name}}

  @spec ok?(keyword()) :: boolean()
  def ok?(opts \\ []), do: match?({:ok, _}, run_all(opts))

  defp format_check(opts) do
    paths = Keyword.get(opts, :format_paths, ["*.exs", "{config,lib,test}/**/*.{ex,exs}"])

    stale = Vibe.Code.Checks.Format.stale_files(paths)

    status = if stale == [], do: :ok, else: :error
    %Result{name: :format, status: status, details: %{stale: stale}}
  end

  defp credo_check(opts) do
    case ensure_optional_app(:credo) do
      :ok -> run_credo(opts)
      {:error, reason} -> %Result{name: :credo, status: :error, details: reason}
    end
  end

  defp ast_patterns_check(opts) do
    paths = Keyword.get(opts, :ast_paths, ["lib/**/*.ex", "test/**/*.exs"])

    patterns =
      Keyword.get(opts, :ast_patterns, %{
        dbg: "dbg(_)",
        pry: "IEx.pry()"
      })

    matches =
      Vibe.Code.AST.search_many(paths, patterns,
        allow_broad: true,
        limit: Keyword.get(opts, :ast_pattern_limit, 50)
      )

    status = if matches == [], do: :ok, else: :error
    %Result{name: :ast_patterns, status: status, details: %{matches: matches}}
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

    details =
      %{files: length(files), errors: errors}
      |> maybe_put_reach_project_details(files, opts, errors)

    %Result{name: :reach, status: status, details: details}
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

  defp maybe_put_reach_project_details(details, _files, _opts, [_error | _rest]), do: details

  defp maybe_put_reach_project_details(details, files, opts, []) do
    if Keyword.get(opts, :reach_project?, true) do
      Map.put(details, :project, reach_project_details(files, opts))
    else
      details
    end
  end

  defp reach_project_details(files, opts) do
    project = eval_optional("Reach.Project.from_sources(files)", files: files)
    otp = eval_optional("Reach.OTP.Analysis.run(project, nil)", project: project)
    concurrency = eval_optional("Reach.OTP.Concurrency.analyze(project)", project: project)
    smells = eval_optional("Reach.Check.Smells.analyze(project)", project: project)

    %{
      modules: map_size(project.modules),
      nodes: map_size(project.nodes),
      otp: reach_otp_summary(otp),
      concurrency: reach_concurrency_summary(concurrency),
      smells: Enum.take(List.wrap(smells), Keyword.get(opts, :reach_smell_limit, 10))
    }
  rescue
    exception -> %{error: Exception.format(:error, exception, __STACKTRACE__)}
  end

  defp reach_otp_summary(otp) do
    %{
      behaviours: count_detail(Map.get(otp, :behaviours, [])),
      state_machines: count_detail(Map.get(otp, :state_machines, [])),
      missing_handlers: count_detail(Map.get(otp, :missing_handlers, [])),
      hidden_coupling: count_detail(Map.get(otp, :hidden_coupling, [])),
      dead_replies: count_detail(Map.get(otp, :dead_replies, [])),
      cross_process: count_detail(Map.get(otp, :cross_process, []))
    }
  end

  defp reach_concurrency_summary(concurrency) do
    tasks = Map.get(concurrency, :tasks, %{})
    monitors = Map.get(concurrency, :monitors, %{})

    %{
      tasks: count_detail(Map.get(tasks, :async, [])),
      unpaired_tasks: Map.get(tasks, :unpaired, 0),
      monitors: count_detail(Map.get(monitors, :monitors, [])),
      spawns: count_detail(Map.get(concurrency, :spawns, [])),
      supervisors: count_detail(Map.get(concurrency, :supervisors, [])),
      edges: Map.get(concurrency, :concurrency_edges, %{})
    }
  end

  defp count_detail(value) when is_list(value), do: length(value)
  defp count_detail(value) when is_map(value), do: map_size(value)
  defp count_detail(nil), do: 0
  defp count_detail(_value), do: 1

  defp graph_node_count(graph), do: graph |> reach_nodes() |> length()

  defp reach_file_to_graph(file), do: eval_optional("Reach.file_to_graph(file)", file: file)

  defp reach_nodes(graph), do: eval_optional("Reach.nodes(graph)", graph: graph)

  defp ex_slop_check(opts) do
    case ensure_optional_app(:credo) do
      :ok -> run_ex_slop(opts)
      {:error, reason} -> %Result{name: :ex_slop, status: :error, details: reason}
    end
  end

  defp ex_dna_check(opts) do
    case ensure_optional_app(:ex_dna) do
      :ok -> run_ex_dna(opts)
      {:error, reason} -> %Result{name: :ex_dna, status: :error, details: reason}
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
    %Result{name: :ex_slop, status: status, details: %{issues: Enum.map(issues, &issue_to_map/1)}}
  end

  defp run_ex_dna(opts) do
    paths = Keyword.get(opts, :paths, ["lib", "test"])
    min_mass = Keyword.get(opts, :ex_dna_min_mass, 80)

    report =
      eval_optional("ExDNA.analyze(paths: paths, reporters: [], min_mass: min_mass)",
        paths: paths,
        min_mass: min_mass
      )

    clones = Map.get(report, :clones, [])
    status = if clones == [], do: :ok, else: :error

    %Result{
      name: :ex_dna,
      status: status,
      details: %{stats: Map.get(report, :stats), clones: clones}
    }
  end

  defp ex_slop_checks do
    config = credo_config()
    checks = get_in(config, [:checks, :extra]) || []
    disabled = config |> get_in([:checks, :disabled]) |> List.wrap() |> Enum.map(&check_module/1)

    checks
    |> Enum.flat_map(&expand_ex_slop_check/1)
    |> Enum.reject(&(&1 in disabled))
    |> Enum.uniq()
  end

  defp expand_ex_slop_check({ExSlop, _params}) do
    if Code.ensure_loaded?(ExSlop) do
      # ExSlop is dev/test-only, so production builds must avoid a static remote call.
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(ExSlop, :recommended_checks, [])
    else
      []
    end
  end

  defp expand_ex_slop_check(check) do
    module = check_module(check)

    if String.starts_with?(Atom.to_string(module), "Elixir.ExSlop.") do
      [module]
    else
      []
    end
  end

  defp credo_config do
    case Code.eval_file(".credo.exs") do
      {%{configs: [config | _]}, _binding} -> config
      {_config, _binding} -> %{}
    end
  end

  defp check_module({module, _opts}), do: module
  defp check_module(module), do: module

  defp summarize_result(%Result{name: name, status: status, details: details}) do
    %Result{name: name, status: status, count: detail_count(details)}
  end

  defp failure_report(%Result{name: name, details: details}) do
    %Result{name: name, details: compact_details(details)}
  end

  defp detail_count(%{matches: matches}) when is_list(matches), do: length(matches)
  defp detail_count(%{issues: issues}) when is_list(issues), do: length(issues)
  defp detail_count(%{clones: clones}) when is_list(clones), do: length(clones)
  defp detail_count(%{stale: stale}) when is_list(stale), do: length(stale)
  defp detail_count(%{output: output}) when is_binary(output), do: byte_size(output)
  defp detail_count(_details), do: nil

  defp compact_details(%{output: output} = details) when is_binary(output) do
    %{details | output: String.slice(output, 0, @max_failure_output_chars)}
  end

  defp compact_details(%{matches: matches} = details) when is_list(matches),
    do: %{details | matches: Enum.take(matches, @max_issue_details)}

  defp compact_details(%{issues: issues} = details) when is_list(issues),
    do: %{details | issues: Enum.take(issues, @max_issue_details)}

  defp compact_details(%{clones: clones} = details) when is_list(clones),
    do: %{details | clones: Enum.take(clones, @max_clone_details)}

  defp compact_details(details), do: details

  defp mix_check(name, task, args, _opts) do
    Mix.Task.clear()

    try do
      {_output, result} = capture_io(fn -> Mix.Task.run(task, args) end)
      %Result{name: name, status: :ok, details: %{result: result}}
    rescue
      exception ->
        %{
          name: name,
          status: :error,
          details: Exception.format(:error, exception, __STACKTRACE__)
        }
    catch
      :exit, reason -> %Result{name: name, status: :error, details: reason}
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
    {opts, _args, _invalid} = OptionParser.parse(argv, strict: [mute_exit_status: :boolean])

    if opts[:mute_exit_status], do: argv, else: ["--mute-exit-status" | argv]
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
