defmodule Exy.CLI.Subagents do
  @moduledoc "Subagent listing and inspection for CLI."
  alias Exy.CLI.{Output, Server}

  @spec command([String.t()], keyword()) :: :ok | {:error, term()}
  def command(["jobs"], opts), do: print_server_result(server_call(&Exy.Subagents.jobs/0), opts)

  def command(["active"], opts),
    do: print_server_result(server_call(&Exy.Subagents.active/0), opts)

  def command(["schedules"], opts),
    do: print_server_result(server_call(&Exy.Subagents.scheduled/0), opts)

  def command(["cancel", id], opts) do
    Output.print(server_call(fn -> Exy.Subagents.cancel(id) end), opts)
  end

  def command(["status", id], opts) do
    Output.print(server_call(fn -> Exy.Subagents.status(id) end), opts)
  end

  def command(["result", id], opts) do
    Output.print(server_call(fn -> Exy.Subagents.result(id) end), opts)
  end

  def command(_args, _opts) do
    Output.error("Usage: exy subagents jobs|active|schedules|status <id>|result <id>|cancel <id>")
    {:error, :invalid_subagents_command}
  end

  defp print_server_result({:error, _reason} = error, opts), do: Output.print(error, opts)
  defp print_server_result(result, opts), do: Output.print({:ok, result}, opts)

  defp server_call(fun) do
    case Server.ensure_running() do
      :ok -> fun.()
      {:error, reason} -> {:error, {:server_not_running, reason}}
    end
  end
end
