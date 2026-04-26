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

  def command(["import", source, path], opts) do
    Output.print(Exy.Storage.Import.import_path(source, path), opts)
  end

  def command(_args, _opts) do
    Output.error("Usage: exy storage migrate|status|import pi <path>")
    {:error, :invalid_storage_command}
  end

  defp run(fun) do
    {:ok, fun.()}
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  end
end
