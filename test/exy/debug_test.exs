defmodule Exy.DebugTest do
  use ExUnit.Case, async: true

  require Exy.Debug

  test "compile-time debug is enabled outside prod" do
    assert Exy.Debug.enabled?()
  end

  test "run macro evaluates debug block when enabled" do
    result =
      Exy.Debug.run :disabled do
        :enabled
      end

    assert result == :enabled
  end
end
