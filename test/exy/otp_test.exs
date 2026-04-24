defmodule Exy.OTPTest do
  use ExUnit.Case, async: true

  test "runtime info is available" do
    info = Exy.OTP.runtime_info()
    assert info.elixir == System.version()
    assert is_integer(info.process_count)
  end
end
