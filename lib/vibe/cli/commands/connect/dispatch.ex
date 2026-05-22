defmodule Vibe.CLI.Commands.Connect.Dispatch do
  @moduledoc false

  @spec action([String.t()], keyword()) :: tuple()
  def action(["connect", "--ssh", target], opts), do: {:ssh, target, opts}
  def action(["connect", "--dist", target], _opts), do: {:distribution, target}

  def action(["connect", target], opts) do
    if opts[:ssh], do: {:ssh, target, opts}, else: {:distribution, target}
  end

  def action(["connect"], _opts), do: {:list_known_nodes}
  def action(_args, _opts), do: {:invalid}
end
