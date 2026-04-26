defmodule Exy.CLI do
  @moduledoc false

  @spec main([String.t()]) :: :ok | {:error, term()}
  def main(argv) do
    argv
    |> Exy.CLI.Parser.parse()
    |> Exy.CLI.Command.dispatch()
  end

  @doc false
  def parse(argv), do: Exy.CLI.Parser.parse(argv)
end
