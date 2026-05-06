defmodule Vibe.Plugin.Discovery do
  @moduledoc "Automatic plugin module discovery from loaded applications."
  @spec builtin() :: [module()]
  def builtin do
    :vibe
    |> Application.spec(:modules)
    |> List.wrap()
    |> Enum.filter(&builtin_plugin?/1)
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
