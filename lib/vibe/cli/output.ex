defmodule Vibe.CLI.Output do
  @moduledoc "CLI output formatting: ok/error results, tables, JSON."

  @spec print(term(), keyword()) :: :ok | {:error, term()}
  def print(result, opts) do
    {device, message, reply} = Vibe.CLI.Output.Payload.build(result, opts)
    puts(device, message)
    reply
  end

  @spec error(String.t()) :: :ok
  def error(message), do: puts(:stderr, "error: #{message}")

  defp puts(device, message) do
    IO.puts(device, message)
  rescue
    ErlangError -> :ok
  catch
    :exit, _reason -> :ok
  end
end
