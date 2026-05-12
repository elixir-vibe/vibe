defmodule Vibe.Plugin.Discovery do
  @moduledoc """
  Automatic plugin module discovery from loaded applications.

  All `Vibe.Plugins.*` modules that implement `handle_event/3` are loaded
  by default. To disable specific plugins:

      config :vibe, :disabled_plugins, [Vibe.Plugins.Notify]
  """

  @spec builtin() :: [module()]
  def builtin do
    disabled =
      Application.get_env(:vibe, :disabled_plugins, [])
      |> Vibe.Support.Lists.join(profile_disabled())
      |> MapSet.new()

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

  defp profile_disabled do
    Vibe.Agent.Profile.disabled_plugins()
  rescue
    error ->
      require Logger
      Logger.warning("Failed to load disabled_plugins from profile: #{Exception.message(error)}")
      []
  end
end
