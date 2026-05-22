defmodule Vibe.Plugin.WaitersTest do
  use ExUnit.Case, async: false

  @table :vibe_test_plugin_waiters

  setup do
    if :ets.info(@table) != :undefined, do: :ets.delete(@table)
    on_exit(fn -> if :ets.info(@table) != :undefined, do: :ets.delete(@table) end)
    :ok
  end

  test "waiter tables are owned by the supervised waiter registry" do
    assert :ok = Vibe.Plugin.Waiters.ensure_table!(@table)
    assert :ets.info(@table, :owner) == Process.whereis(Vibe.Plugin.Waiters)
  end

  test "register pop and unregister keep existing API" do
    assert :ok = Vibe.Plugin.Waiters.register(@table, "session", self())
    assert {:ok, pid} = Vibe.Plugin.Waiters.pop(@table, "session")
    assert pid == self()
    assert :error = Vibe.Plugin.Waiters.pop(@table, "session")

    assert :ok = Vibe.Plugin.Waiters.register(@table, "session", self())
    assert :ok = Vibe.Plugin.Waiters.unregister(@table, "session")
    assert :error = Vibe.Plugin.Waiters.pop(@table, "session")
  end
end
