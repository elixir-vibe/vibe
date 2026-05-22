defmodule Vibe.CLI.Commands.Connect.DispatchTest do
  use ExUnit.Case, async: true

  alias Vibe.CLI.Commands.Connect.Dispatch

  test "classifies connect target actions" do
    assert Dispatch.action(["connect", "--ssh", "host:22"], yes: true) ==
             {:ssh, "host:22", [yes: true]}

    assert Dispatch.action(["connect", "--dist", "node@host"], []) == {:distribution, "node@host"}
    assert Dispatch.action(["connect", "target"], ssh: true) == {:ssh, "target", [ssh: true]}
    assert Dispatch.action(["connect", "target"], []) == {:distribution, "target"}
    assert Dispatch.action(["connect"], []) == {:list_known_nodes}
    assert Dispatch.action(["connect", "a", "b"], []) == {:invalid}
  end
end
