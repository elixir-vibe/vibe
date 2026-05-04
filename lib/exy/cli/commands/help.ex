defmodule Exy.CLI.Commands.Help do
  @moduledoc "CLI `help` command: built-in topic browser."
  @behaviour Exy.CLI.Command

  @impl true
  def names, do: ["help", "docs"]

  @impl true
  def run([_command], _opts), do: IO.write(Exy.Docs.index())

  def run([_command, topic | _rest], _opts) do
    IO.write(Exy.Docs.render(topic))
  end
end
