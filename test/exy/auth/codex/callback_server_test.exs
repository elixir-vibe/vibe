defmodule Exy.Auth.Codex.CallbackServerTest do
  use ExUnit.Case, async: false

  @shutdown_assert_timeout_ms 1_000

  test "stop terminates the callback accept process" do
    assert {:ok, pid} = Exy.Auth.Codex.CallbackServer.start_link("state")
    assert Process.alive?(pid)
    assert true = Exy.Auth.Codex.CallbackServer.stop(pid)
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, reason}, @shutdown_assert_timeout_ms
    assert reason in [:shutdown, :noproc]
  end
end
