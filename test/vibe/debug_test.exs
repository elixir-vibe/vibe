defmodule Vibe.DebugTest do
  use ExUnit.Case, async: true

  require Vibe.Debug

  test "compile-time debug is enabled outside prod" do
    assert Vibe.Debug.enabled?()
  end

  test "run macro evaluates debug block when enabled" do
    result =
      Vibe.Debug.run :disabled do
        :enabled
      end

    assert result == :enabled
  end
end
