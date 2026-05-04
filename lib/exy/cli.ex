defmodule Exy.CLI do
  @moduledoc "CLI entrypoint for argv parsing and command dispatch."
  @spec main([String.t()]) :: :ok | {:error, term()}
  def main(argv) do
    argv
    |> Exy.CLI.Parser.parse()
    |> Exy.CLI.Command.dispatch()
  end

  @doc """
  Parses CLI arguments without dispatching a command.
  """
  def parse(argv), do: Exy.CLI.Parser.parse(argv)
end
