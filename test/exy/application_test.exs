defmodule Exy.ApplicationTest do
  use ExUnit.Case, async: false

  test "configures dependency logging below verbose action dumps" do
    assert Application.get_env(:jido, :telemetry)[:log_level] == :error
    assert Application.get_env(:jido, :telemetry)[:log_args] == :none
    assert Application.get_env(:jido, :observability)[:log_level] == :warning
  end

  test "starts both default and Exy-scoped Jido supervisors" do
    assert Process.whereis(Jido.AgentSupervisor)
    assert Process.whereis(Exy.Jido.AgentSupervisor)
  end
end
