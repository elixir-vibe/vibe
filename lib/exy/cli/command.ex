defmodule Exy.CLI.Command do
  @moduledoc "CLI command dispatch and behaviour definition."
  @callback names() :: [String.t()]
  @callback run([String.t()], keyword()) :: :ok | {:error, term()}

  alias Exy.CLI.Commands
  alias Exy.CLI.Output

  @commands [
    Commands.Help,
    Commands.Server,
    Commands.New,
    Commands.Sessions,
    Commands.Storage,
    Commands.Search,
    Commands.TUITrace,
    Commands.Gateway,
    Commands.Skill,
    Commands.Subagents,
    Commands.Send,
    Commands.Attach
  ]

  @spec dispatch(Exy.CLI.Parser.parsed()) :: :ok | {:error, term()}
  def dispatch(%{invalid: invalid}) when invalid != [] do
    Enum.each(invalid, fn {flag, _} -> Output.error("Unknown option: #{flag}") end)
    {:error, :invalid_args}
  end

  def dispatch(%{args: [name | _rest] = args, opts: opts}) do
    case Enum.find(@commands, &(name in &1.names())) do
      nil -> Commands.Default.run(args, opts)
      command -> command.run(args, opts)
    end
  end

  def dispatch(%{args: [], opts: opts}), do: Commands.Default.run([], opts)
end
