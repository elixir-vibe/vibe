defmodule Vibe.Tool.PluginHooksTest do
  use ExUnit.Case, async: false

  defmodule ModifyPlugin do
    use Vibe.Plugin

    @impl true
    def tool_call(%{args: args} = call, _context, state) do
      {:ok, %{call | args: Map.put(args, :path, "modified.txt")}, state}
    end

    @impl true
    def tool_result(_result, _context, state) do
      {:ok, %{result: %{path: "from-plugin"}}, state}
    end
  end

  defmodule BlockPlugin do
    use Vibe.Plugin

    @impl true
    def tool_call(_call, _context, state), do: {:block, "blocked by test", state}
  end

  setup do
    on_exit(fn ->
      Vibe.Plugin.Manager.unload(ModifyPlugin)
      Vibe.Plugin.Manager.unload(BlockPlugin)
    end)

    :ok
  end

  test "applies modified tool calls and results at execution boundary" do
    assert :ok = Vibe.Plugin.Manager.load(ModifyPlugin)

    assert {:ok, %{path: "from-plugin"}} =
             Vibe.Tool.PluginHooks.run(:read, %{path: "original.txt"}, %{}, fn params ->
               {:ok, %{path: params.path}}
             end)
  end

  test "blocked tool calls do not execute" do
    assert :ok = Vibe.Plugin.Manager.load(BlockPlugin)

    assert {:ok, %{error: error}} =
             Vibe.Tool.PluginHooks.run(:write, %{path: "danger.txt"}, %{}, fn _params ->
               flunk("blocked tool executed")
             end)

    assert error =~ "blocked by test"
  end
end
