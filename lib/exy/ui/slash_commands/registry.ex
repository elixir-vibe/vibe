defmodule Exy.UI.SlashCommands.Registry do
  @moduledoc false

  @builtin [
    Exy.UI.SlashCommands.Sessions,
    Exy.UI.SlashCommands.New,
    Exy.UI.SlashCommands.Attach,
    Exy.UI.SlashCommands.Model,
    Exy.UI.SlashCommands.Skill,
    Exy.UI.SlashCommands.Clear,
    Exy.UI.SlashCommands.Compact,
    Exy.UI.SlashCommands.Commands
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
      name == spec.name or name in Map.get(spec, :aliases, [])
    end)
  end

  defp plugin_commands do
    if Process.whereis(Exy.Plugin.Manager) do
      Exy.Plugin.Manager.commands()
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
  end
end
