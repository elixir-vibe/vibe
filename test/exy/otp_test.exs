defmodule Exy.OTPTest do
  use ExUnit.Case, async: true

  test "runtime info is available" do
    info = Exy.OTP.runtime_info()
    assert info.elixir == System.version()
    assert is_integer(info.process_count)
  end

  test "top lists display pids with eval-friendly indexes" do
    assert [%{index: 1, pid: pid} | _] = Exy.OTP.top(:memory, limit: 1)
    assert is_binary(pid)
    assert is_pid(Exy.OTP.process_at(:memory, 1))
  end

  test "process info resolves real pids and explicit pid selectors" do
    assert %{pid: pid} = Exy.OTP.process_info(self())
    assert pid == inspect(self())

    assert %{pid: selector_pid} = Exy.OTP.process_info({:pid, self()})
    assert selector_pid == inspect(self())
  end

  test "process info does not parse inspected pids" do
    assert Exy.OTP.process_info(inspect(self())) == nil
    assert Exy.OTP.process_info("#PID<0.1.0>") == nil
  end

  test "process info resolves registered names without creating atoms" do
    name = :exy_otp_test_registered_process
    Process.register(self(), name)

    assert %{pid: pid} = Exy.OTP.process_info(name)
    assert pid == inspect(self())

    assert %{pid: string_pid} = Exy.OTP.process_info(to_string(name))
    assert string_pid == inspect(self())

    assert %{pid: tuple_pid} = Exy.OTP.process_info({:registered, to_string(name)})
    assert tuple_pid == inspect(self())

    assert Exy.OTP.process_info("definitely_not_an_existing_registered_process") == nil
  after
    Process.unregister(:exy_otp_test_registered_process)
  end
end
