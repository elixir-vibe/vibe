defmodule Exy.CLI.Storage do
  @moduledoc false

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
    Output.print(run(fn -> Exy.Storage.FTS.rebuild() end), opts)
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
    Output.print(Exy.Storage.Import.import_path(source, path), opts)
  end

  def command(_args, _opts) do
    Output.error(
      "Usage: exy storage migrate|status|checkpoint|vacuum|fts status|fts rebuild|fts optimize|search <query>|import pi <path>"
    )

    {:error, :invalid_storage_command}
  end

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
