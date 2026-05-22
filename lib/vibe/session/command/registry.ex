defmodule Vibe.Session.Command.Registry do
  @moduledoc "Slash command registry: discovery and dispatch."
  @builtin [
    Vibe.Session.Command.Sessions,
    Vibe.Session.Command.New,
    Vibe.Session.Command.Attach,
    Vibe.Session.Command.Model,
    Vibe.Session.Command.Effort,
    Vibe.Session.Command.Skill,
    Vibe.Session.Command.Goal,
    Vibe.Session.Command.Clear,
    Vibe.Session.Command.Compact,
    Vibe.Session.Command.Background,
    Vibe.Session.Command.Branch,
    Vibe.Session.Command.Web,
    Vibe.Session.Command.Commands,
    Vibe.Session.Command.Help
  ]

  @spec commands() :: [module()]
  def commands do
    (@builtin ++ plugin_commands())
    |> Enum.filter(&command_module?/1)
    |> Enum.uniq()
  end

  @spec specs() :: [map()]
  def specs, do: Enum.map(commands(), &normalize_spec(&1.spec()))

  @spec find(String.t()) :: module() | nil
  def find(name) when is_binary(name) do
    name = String.trim_leading(name, "/")

    Enum.find(commands(), fn module ->
      spec = normalize_spec(module.spec())
      name == spec.name or name in spec.aliases
    end)
  end

  @spec find_selector(atom()) :: module() | nil
  def find_selector(selector) when is_atom(selector) do
    Enum.find(commands(), fn module ->
      selector in normalize_spec(module.spec()).selectors
    end)
  end

  def find_selector(_selector), do: nil

  defp plugin_commands do
    if Process.whereis(Vibe.Plugin.Manager) do
      GenServer.call(Vibe.Plugin.Manager, :commands)
    else
      []
    end
  rescue
    _ -> []
  end

  defp command_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :spec, 0) and
      function_exported?(module, :run, 2)
  end

  defp command_module?(_module), do: false

  defp normalize_spec(spec) do
    spec
    |> Map.put_new(:aliases, [])
    |> Map.put_new(:description, "")
    |> Map.put_new(:selectors, [])
  end
end
