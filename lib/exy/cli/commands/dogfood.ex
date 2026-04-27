defmodule Exy.CLI.Commands.Dogfood do
  @moduledoc false

  alias Exy.Dogfood.TUI

  require Exy.Debug

  @behaviour Exy.CLI.Command

  @impl true
  def names, do: ["dogfood"]

  @impl true
  def run([_name, "tui"], opts), do: run_tui(nil, opts)
  def run([_name, "tui", scenario], opts), do: run_tui(scenario, opts)
  def run([_name, "scenarios"], _opts), do: IO.puts(Enum.join(TUI.scenarios(), "\n"))

  def run(_args, _opts) do
    IO.puts("""
    Usage:
      exy dogfood scenarios
      exy dogfood tui [scenario]

    Options:
      --trace-tui DIR  Write dogfood traces under DIR

    Scenarios:
      #{Enum.join(TUI.scenarios(), "\n      ")}
    """)

    :ok
  end

  if Exy.Debug.enabled?() do
    defp run_tui(scenario, opts) do
      run_opts =
        []
        |> maybe_put(:scenario, scenario)
        |> maybe_put(:dir, opts[:trace_tui])

      {:ok, results} = TUI.run(run_opts)
      IO.puts(render_results(results))

      if Enum.any?(results, &(&1.status == :fail)) do
        {:error, :dogfood_failed}
      else
        :ok
      end
    end

    defp render_results(results) do
      header = "STATUS  SCENARIO              TRACE"

      rows =
        Enum.map(results, fn result ->
          status = result.status |> to_string() |> String.upcase() |> String.pad_trailing(6)
          name = result.name |> String.pad_trailing(20)
          "#{status}  #{name}  #{result.trace_dir}"
        end)

      report_dir = results |> List.first() |> Map.get(:trace_dir, "") |> Path.dirname()

      ([header | rows] ++ ["", "Report: #{Path.join(report_dir, "report.md")}"])
      |> Enum.join("\n")
    end

    defp maybe_put(opts, _key, nil), do: opts
    defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
  else
    defp run_tui(_scenario, _opts) do
      Exy.CLI.Output.error(
        "TUI dogfood requires compile-time debug mode; run in dev/test, not prod"
      )

      {:error, :debug_not_compiled}
    end
  end
end
