defmodule Exy.CLI.ServerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Exy.CLI.Server

  test "usage includes restart command" do
    output =
      capture_io(:stderr, fn ->
        assert {:error, :invalid_server_command} = Server.command(["wat"], [])
      end)

    assert output =~ "restart [--foreground]"
  end
end
