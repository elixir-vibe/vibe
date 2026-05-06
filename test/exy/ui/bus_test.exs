defmodule Exy.UI.BusTest do
  use ExUnit.Case, async: false

  test "broadcast skips stale session registrations" do
    session_id = "bus-stale-#{System.unique_integer([:positive])}"
    server = spawn(fn -> Process.sleep(:infinity) end)

    assert :ok = Exy.UI.Bus.register(session_id, server)
    Process.exit(server, :kill)
    Process.sleep(20)

    assert :ok = Exy.UI.Bus.notify_all(%{level: :warning, text: "runtime pressure"})
    assert {:error, :not_found} = Exy.UI.Bus.server(session_id)
  end

  test "replacing a session demonitor old server and keeps the replacement" do
    session_id = "bus-replace-#{System.unique_integer([:positive])}"
    old = spawn(fn -> Process.sleep(:infinity) end)
    replacement = spawn(fn -> Process.sleep(:infinity) end)

    assert :ok = Exy.UI.Bus.register(session_id, old)
    assert :ok = Exy.UI.Bus.register(session_id, replacement)
    assert {:ok, ^replacement} = Exy.UI.Bus.server(session_id)

    Process.exit(old, :kill)
    Process.sleep(20)

    assert {:ok, ^replacement} = Exy.UI.Bus.server(session_id)

    assert :ok = Exy.UI.Bus.unregister(session_id, replacement)
    assert {:error, :not_found} = Exy.UI.Bus.server(session_id)

    Process.exit(replacement, :kill)
  end
end
