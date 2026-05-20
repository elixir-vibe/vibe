defmodule Vibe.E2E.CLI.Commands.ConnectSSHTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :integration

  alias Vibe.Remote.KnownNodes
  alias Vibe.Remote.SSH.Daemon

  setup do
    dir =
      Path.join(System.tmp_dir!(), "vibe-connect-ssh-e2e-#{System.unique_integer([:positive])}")

    original_home = Application.get_env(:vibe, :home_dir)
    Application.put_env(:vibe, :home_dir, dir)

    on_exit(fn ->
      if original_home,
        do: Application.put_env(:vibe, :home_dir, original_home),
        else: Application.delete_env(:vibe, :home_dir)

      File.rm_rf!(dir)
    end)

    :ok
  end

  test "connect command reaches an OTP SSH daemon and persists endpoint" do
    password = "secret-#{System.unique_integer([:positive])}"
    {:ok, daemon} = Daemon.start(port: 0, password: password)

    try do
      {:ok, port} = Daemon.port(daemon)

      output =
        capture_io(fn ->
          assert :ok =
                   Vibe.CLI.Commands.Connect.run(
                     ["connect", "--ssh", "127.0.0.1:#{port}"],
                     password: password,
                     yes: true
                   )
        end)

      assert output =~ "Connected to Vibe SSH endpoint 127.0.0.1:#{port}"

      expected_node = "127.0.0.1:#{port}"
      assert [%{"node" => ^expected_node, "transport" => "ssh"}] = KnownNodes.list()
    after
      Daemon.stop(daemon)
    end
  end
end
