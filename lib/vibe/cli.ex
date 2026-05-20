defmodule Vibe.CLI do
  @moduledoc "CLI entrypoint for argv parsing and command dispatch."
  @spec main([String.t()]) :: :ok | {:error, term()}
  def main(argv) do
    argv
    |> Vibe.CLI.Parser.parse()
    |> Vibe.CLI.Command.dispatch()
  end

  @doc """
  Parses CLI arguments without dispatching a command.
  """
  defdelegate parse(argv), to: Vibe.CLI.Parser
end
