defmodule Vibe.Plugin.Discovery do
  @moduledoc """
  Automatic plugin module discovery from loaded applications.

  All `Vibe.Plugins.*` modules that implement `handle_event/3` are loaded
  by default. To disable specific plugins:

      config :vibe, :disabled_plugins, [Vibe.Plugins.Notify]
  """

  @spec builtin() :: [module()]
  def builtin do
    disabled = MapSet.new(Application.get_env(:vibe, :disabled_plugins, []))

    :vibe
    |> Application.spec(:modules)
    |> List.wrap()
    |> Enum.filter(&builtin_plugin?/1)
    |> Enum.reject(&MapSet.member?(disabled, &1))
    |> Enum.sort()
  end

  defp builtin_plugin?(module) do
    case Module.split(module) do
      ["Vibe", "Plugins" | _] ->
        Code.ensure_loaded?(module) and function_exported?(module, :handle_event, 3)

      _ ->
        false
    end
  end
end
