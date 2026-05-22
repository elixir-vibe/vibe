defmodule Vibe.Code.Checks.Runner do
  @moduledoc false

  @default_checks [:format, :compile, :test, :credo, :dialyzer, :ex_dna]

  @spec run_all(keyword(), (atom(), keyword() -> struct())) ::
          {:ok, [struct()]} | {:error, [struct()]}
  def run_all(opts, run_fun) when is_list(opts) and is_function(run_fun, 2) do
    checks = Keyword.get(opts, :checks, @default_checks)
    cwd = Keyword.get(opts, :cwd, File.cwd!())
    results = File.cd!(cwd, fn -> Enum.map(checks, &run_fun.(&1, opts)) end)

    if Enum.all?(results, &(&1.status == :ok)), do: {:ok, results}, else: {:error, results}
  end
end
