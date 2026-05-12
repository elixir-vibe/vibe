defmodule Vibe.Plugin.DiscoveryTest do
  use ExUnit.Case, async: false

  alias Vibe.Plugin.Discovery

  test "builtin discovers Vibe.Plugins.* modules" do
    plugins = Discovery.builtin()
    assert Vibe.Plugins.WebSearch in plugins
    assert Vibe.Plugins.Notify in plugins
    assert Vibe.Plugins.Safety in plugins
    assert Vibe.Plugins.Rules in plugins
    assert Vibe.Plugins.Question in plugins
  end

  test "disabled_plugins config excludes modules" do
    original = Application.get_env(:vibe, :disabled_plugins)
    Application.put_env(:vibe, :disabled_plugins, [Vibe.Plugins.Notify, Vibe.Plugins.Safety])

    plugins = Discovery.builtin()
    refute Vibe.Plugins.Notify in plugins
    refute Vibe.Plugins.Safety in plugins
    assert Vibe.Plugins.WebSearch in plugins

    if original,
      do: Application.put_env(:vibe, :disabled_plugins, original),
      else: Application.delete_env(:vibe, :disabled_plugins)
  end
end
