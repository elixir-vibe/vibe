defmodule Exy.SelfPatch do
  @moduledoc """
  Development-only helpers for patching Exy and continuing in the same BEAM.

  Self-modification must be gated: write or update tests first, run a preflight
  before mutation, then run validation again before hot reload.
  """

  @spec validate(keyword()) :: {:ok, [map()]} | {:error, [map()]}
  def validate(opts \\ []), do: Exy.Checks.run_all(opts)

  @spec preflight(keyword()) :: {:ok, [map()]} | {:error, [map()]}
  def preflight(opts \\ []) do
    opts =
      Keyword.put_new(opts, :checks, [:format, :compile, :test, :credo, :ex_slop, :ex_dna, :reach])

    Exy.Checks.run_all(opts)
  end

  @spec compile_and_reload(keyword()) :: {:ok, [map()]} | {:error, [map()]}
  def compile_and_reload(opts \\ []) do
    checks =
      Keyword.get(opts, :checks, [:format, :compile, :test, :credo, :ex_slop, :ex_dna, :reach])

    with {:ok, results} <- Exy.Checks.run_all(Keyword.put(opts, :checks, checks)) do
      purge_exy_modules()
      Exy.Trajectory.Store.append(:self_patch_validated, %{checks: checks, results: results})
      {:ok, results}
    end
  end

  @spec snapshot_process(pid() | atom()) :: {:ok, term()} | {:error, term()}
  def snapshot_process(process) do
    pid = if is_pid(process), do: process, else: Process.whereis(process)

    cond do
      is_nil(pid) -> {:error, :not_found}
      true -> {:ok, :sys.get_state(pid)}
    end
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp purge_exy_modules do
    :code.all_loaded()
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(&(to_string(&1) |> String.starts_with?("Elixir.Exy")))
    |> Enum.each(fn module ->
      :code.purge(module)
      :code.delete(module)
    end)
  end
end
