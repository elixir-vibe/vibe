defmodule Vibe.Plugins.PluginEventsTest do
  use ExUnit.Case, async: true

  defmodule TestToolCallPlugin do
    use Vibe.Plugin

    @impl true
    def tool_call(%{name: "blocked"}, _context, state),
      do: {:block, "blocked by test", state}

    def tool_call(%{name: "mutated"} = call, _context, state),
      do: {:ok, Map.put(call, :args, %{modified: true}), state}

    def tool_call(_call, _context, state), do: {:ok, state}

    @impl true
    def tool_result(%{output: "replace_me"} = result, _context, state),
      do: {:ok, Map.put(result, :output, "replaced"), state}

    def tool_result(_result, _context, state), do: {:ok, state}

    @impl true
    def context([_, _, _ | _] = messages, _context, state),
      do: {:ok, Enum.take(messages, 2), state}

    def context(_messages, _context, state), do: {:ok, state}
  end

  setup do
    :ok = Vibe.Plugin.Manager.load(TestToolCallPlugin)
    on_exit(fn -> Vibe.Plugin.Manager.unload(TestToolCallPlugin) end)
    :ok
  end

  test "tool_call can block execution" do
    assert {:block, "blocked by test"} =
             Vibe.Plugin.Manager.tool_call(%{name: "blocked"}, %{})
  end

  test "tool_call can mutate args" do
    assert {:ok, %{name: "mutated", args: %{modified: true}}} =
             Vibe.Plugin.Manager.tool_call(%{name: "mutated"}, %{})
  end

  test "tool_call passes through safe calls" do
    assert :ok = Vibe.Plugin.Manager.tool_call(%{name: "safe"}, %{})
  end

  test "tool_result can modify output" do
    assert {:ok, %{output: "replaced"}} =
             Vibe.Plugin.Manager.tool_result(%{output: "replace_me"}, %{})
  end

  test "context can filter messages" do
    messages = [%{role: :user}, %{role: :assistant}, %{role: :user}]

    assert {:ok, [%{role: :user}, %{role: :assistant}]} =
             Vibe.Plugin.Manager.context(messages, %{})
  end

  test "context passes through short lists" do
    assert :ok = Vibe.Plugin.Manager.context([%{role: :user}], %{})
  end
end
