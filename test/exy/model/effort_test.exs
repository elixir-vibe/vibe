defmodule Exy.Model.EffortTest do
  use ExUnit.Case, async: true

  alias Exy.Model.Effort

  test "defines atom-only internal values" do
    assert Effort.values() == [:off, :minimal, :low, :medium, :high, :xhigh]
    assert Effort.default() == :medium
    assert Effort.valid?(:high)
    refute Effort.valid?("high")
  end

  test "parses boundary strings" do
    assert Effort.from_string("high") == {:ok, :high}
    assert Effort.from_string(" Medium ") == {:ok, :medium}
    assert Effort.from_string("bad") == {:error, {:unknown_effort, "bad"}}
  end
end
