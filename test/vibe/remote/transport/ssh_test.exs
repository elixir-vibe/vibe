defmodule Vibe.Remote.Transport.SSHTest do
  use ExUnit.Case, async: true

  test "rejects missing target" do
    assert {:error, :missing_ssh_target} = Vibe.Remote.connect(transport: :ssh)
  end
end
