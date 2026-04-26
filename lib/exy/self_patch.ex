defmodule Exy.SelfPatch do
  @moduledoc """
  Development-only helpers for patching Exy and continuing in the same BEAM.

  Self-modification must be gated: write or update tests first, run a preflight
  before mutation, then run validation again before hot reload.
  """

  @type reload_report :: %{
          checks: map(),
          modules: [module()],
          snapshots: map(),
          warnings: [term()]
        }

  @spec validate(keyword()) :: {:ok, map()} | {:error, map()}
  def validate(opts \\ []) do
    report = Exy.Code.Checks.analyze(opts)
    if report.ok?, do: {:ok, report}, else: {:error, report}
  end

  @spec preflight(keyword()) :: {:ok, map()} | {:error, map()}
  def preflight(opts \\ []) do
    opts = Keyword.put_new(opts, :checks, full_checks())
    validate(opts)
  end

  @spec compile_and_reload(keyword()) :: {:ok, reload_report()} | {:error, map()}
  def compile_and_reload(opts \\ []) do
    opts = Keyword.put_new(opts, :checks, full_checks())

    with {:ok, check_report} <- validate(opts),
         {:ok, modules} <- compile_project(opts) do
      modules = reloadable_modules(modules, opts)
      snapshots = snapshot_registered_processes(modules)
      warnings = hot_reload_modules(modules)

      report = %{checks: check_report, modules: modules, snapshots: snapshots, warnings: warnings}
      Exy.Trajectory.Store.append(:self_patch_reloaded, report)
      {:ok, report}
    end
  end

  @spec deployment_gate(keyword()) :: {:ok, map()} | {:error, map()}
  def deployment_gate(opts \\ []) do
    opts
    |> Keyword.put_new(:checks, full_checks())
    |> Exy.Code.Checks.analyze()
    |> case do
      %{ok?: true} = report -> {:ok, report}
      report -> {:error, report}
    end
  end

  @spec release_reload(keyword()) :: {:ok, term()} | {:error, term()}
  def release_reload(opts \\ []) do
    vsn = opts |> Keyword.get(:vsn, Application.spec(:exy, :vsn)) |> to_charlist()
    :release_handler.install_release(vsn)
  end

  @spec snapshot_process(pid() | atom()) :: {:ok, term()} | {:error, term()}
  def snapshot_process(process) do
    pid = if is_pid(process), do: process, else: Process.whereis(process)

    if is_nil(pid) do
      {:error, :not_found}
    else
      {:ok, :sys.get_state(pid)}
    end
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp full_checks, do: [:format, :compile, :test, :credo, :ex_slop, :ex_dna, :reach]

  defp compile_project(opts) do
    Mix.Task.clear()

    try do
      modules = Mix.Task.run("compile", Keyword.get(opts, :compile_args, []))
      {:ok, List.wrap(modules)}
    rescue
      exception -> {:error, %{compile_error: Exception.format(:error, exception, __STACKTRACE__)}}
    catch
      :exit, reason -> {:error, %{compile_exit: reason}}
    end
  end

  defp reloadable_modules([], _opts), do: exy_modules()
  defp reloadable_modules(modules, opts), do: Enum.filter(modules, &reloadable_module?(&1, opts))

  defp reloadable_module?(module, opts) do
    prefixes = Keyword.get(opts, :module_prefixes, ["Elixir.Exy"])
    Enum.any?(prefixes, &(module |> to_string() |> String.starts_with?(&1)))
  end

  defp exy_modules do
    :exy
    |> Application.spec(:modules)
    |> List.wrap()
    |> Enum.filter(&reloadable_module?(&1, []))
  end

  defp snapshot_registered_processes(modules) do
    modules
    |> Enum.flat_map(fn module ->
      case Process.whereis(module) do
        nil -> []
        pid -> [{module, safe_snapshot(pid)}]
      end
    end)
    |> Map.new()
  end

  defp safe_snapshot(pid) do
    case snapshot_process(pid) do
      {:ok, state} -> state
      {:error, reason} -> {:snapshot_failed, reason}
    end
  end

  defp hot_reload_modules(modules) do
    Enum.flat_map(modules, &hot_reload_module/1)
  end

  defp hot_reload_module(module) do
    if :code.soft_purge(module) do
      :code.delete(module)
      :code.ensure_loaded(module)
      []
    else
      [{:old_code_still_running, module}]
    end
  end
end
