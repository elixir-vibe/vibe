defmodule Exy.CLI.Storage do
  @moduledoc "Internal implementation module."
  alias Exy.CLI.Output

  @spec command([String.t()], keyword()) :: :ok | {:error, term()}
  def command(["migrate"], opts) do
    Output.print(run(fn -> Exy.Storage.migrate!() end), opts)
  end

  def command(["status"], opts) do
    Output.print(run(&Exy.Storage.status/0), opts)
  end

  def command(["checkpoint"], opts) do
    Output.print(run(fn -> Exy.Storage.checkpoint!() end), opts)
  end

  def command(["vacuum"], opts) do
    Output.print(run(fn -> Exy.Storage.vacuum!() end), opts)
  end

  def command(["fts", "status"], opts) do
    Output.print(run(&Exy.Storage.FTS.status/0), opts)
  end

  def command(["fts", "rebuild"], opts) do
    Output.print(run(fn -> Exy.Storage.FTS.rebuild(progress: progress_fun(opts)) end), opts)
  end

  def command(["fts", "optimize"], opts) do
    Output.print(run(fn -> Exy.Storage.FTS.optimize() end), opts)
  end

  def command(["search" | query_parts], opts) when query_parts != [] do
    query = Enum.join(query_parts, " ")

    Output.print(
      Exy.Storage.Search.query(query,
        cwd: opts[:cwd],
        roles: search_roles(opts),
        include_tools: opts[:include_tools] == true,
        limit: opts[:limit] || 10
      ),
      opts
    )
  end

  def command(["import", source, path], opts) do
    Output.print(Exy.Storage.Import.import_path(source, path, import_opts(opts)), opts)
  end

  def command(_args, _opts) do
    Output.error(
      "Usage: exy storage migrate|status|checkpoint|vacuum|fts status|fts rebuild|fts optimize|search <query>|import pi <path> [--no-fts] [--rebuild-fts] [--batch-size N]"
    )

    {:error, :invalid_storage_command}
  end

  defp import_opts(opts) do
    [
      index?: opts[:no_fts] != true,
      rebuild_fts?: opts[:no_fts] != true or opts[:rebuild_fts] == true,
      progress: progress_fun(opts),
      progress_interval: opts[:batch_size] || 50
    ]
  end

  defp progress_fun(opts) do
    if opts[:mode] == "json" do
      nil
    else
      &print_progress/1
    end
  end

  defp print_progress(%{phase: :scan, total: total}),
    do: IO.puts(:stderr, "import: found #{total} JSONL files")

  defp print_progress(%{phase: :import} = event) do
    IO.puts(
      :stderr,
      "import: #{event.current}/#{event.total} files, #{event.imported} imported, #{event.skipped} skipped, #{event.events} events, #{event.errors} errors"
    )
  end

  defp print_progress(%{phase: :fts_rebuild}), do: IO.puts(:stderr, "import: rebuilding FTS")
  defp print_progress(%{phase: :fts_optimize}), do: IO.puts(:stderr, "import: optimizing FTS")

  defp print_progress(%{phase: :fts_rebuild_start} = event),
    do:
      IO.puts(
        :stderr,
        "fts: rebuilding #{event.ui_events} ui events and #{event.memories} memories"
      )

  defp print_progress(%{phase: :fts_ui_events, indexed: indexed}),
    do: IO.puts(:stderr, "fts: indexed #{indexed} ui events")

  defp print_progress(%{phase: :fts_memories, indexed: indexed}),
    do: IO.puts(:stderr, "fts: indexed #{indexed} memories")

  defp print_progress(%{phase: :fts_rebuild_done} = event),
    do:
      IO.puts(:stderr, "fts: rebuilt #{event.ui_events} ui events and #{event.memories} memories")

  defp print_progress(%{phase: :done} = event),
    do:
      IO.puts(
        :stderr,
        "import: done, #{event.imported} imported, #{event.skipped} skipped, #{event.events} events"
      )

  defp print_progress(_event), do: :ok

  defp search_roles(opts) do
    cond do
      opts[:role] -> [opts[:role]]
      opts[:include_tools] == true -> [:user, :assistant, :tool]
      true -> [:user, :assistant]
    end
  end

  defp run(fun) do
    {:ok, fun.()}
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  end
end
