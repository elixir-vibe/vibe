defmodule Exy.Auth.Codex.CallbackServerTest do
  use ExUnit.Case, async: false

  test "stop terminates the callback accept process" do
    assert {:ok, pid} = Exy.Auth.Codex.CallbackServer.start_link("state")
    assert Process.alive?(pid)
    assert true = Exy.Auth.Codex.CallbackServer.stop(pid)
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, reason}, 1_000
    assert reason in [:shutdown, :noproc]
  end
end
