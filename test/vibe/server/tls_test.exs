defmodule Vibe.Server.TLSTest do
  use ExUnit.Case, async: false

  alias Vibe.Server.TLS

  setup do
    dir = Path.join(System.tmp_dir!(), "vibe-tls-test-#{System.unique_integer([:positive])}")
    original_home = Application.get_env(:vibe, :home_dir)
    Application.put_env(:vibe, :home_dir, dir)

    on_exit(fn ->
      if original_home,
        do: Application.put_env(:vibe, :home_dir, original_home),
        else: Application.delete_env(:vibe, :home_dir)

      File.rm_rf!(dir)
    end)

    %{dir: dir}
  end

  test "ensure! generates CA and node certificates" do
    assert :ok = TLS.ensure!()
    assert File.exists?(TLS.ca_cert_path())
    assert File.exists?(TLS.ca_key_path())
    assert File.exists?(TLS.node_cert_path())
    assert File.exists?(TLS.node_key_path())
    assert File.exists?(TLS.dist_config_path())
  end

  test "CA key has restricted permissions" do
    TLS.ensure!()
    %{mode: mode} = File.stat!(TLS.ca_key_path())
    assert Bitwise.band(mode, 0o077) == 0
  end

  test "ensure! is idempotent" do
    TLS.ensure!()
    ca_before = File.read!(TLS.ca_cert_path())
    TLS.ensure!()
    assert File.read!(TLS.ca_cert_path()) == ca_before
  end

  test "dist_config contains cert paths" do
    TLS.ensure!()
    config = File.read!(TLS.dist_config_path())
    assert config =~ "certfile"
    assert config =~ "cacertfile"
    assert config =~ "verify_peer"
  end

  test "generated certificates enable mutual TLS" do
    TLS.ensure!()
    c = &String.to_charlist/1

    {:ok, listen} =
      :ssl.listen(0, [
        {:certfile, c.(TLS.node_cert_path())},
        {:keyfile, c.(TLS.node_key_path())},
        {:cacertfile, c.(TLS.ca_cert_path())},
        {:verify, :verify_peer},
        {:fail_if_no_peer_cert, true}
      ])

    {:ok, {_, port}} = :ssl.sockname(listen)

    task =
      Task.async(fn ->
        {:ok, socket} = :ssl.transport_accept(listen)
        :ssl.handshake(socket)
      end)

    result =
      :ssl.connect(
        ~c"127.0.0.1",
        port,
        [
          {:certfile, c.(TLS.node_cert_path())},
          {:keyfile, c.(TLS.node_key_path())},
          {:cacertfile, c.(TLS.ca_cert_path())},
          {:verify, :verify_peer},
          {:server_name_indication, :disable}
        ],
        5000
      )

    assert {:ok, _socket} = result
    assert {:ok, _socket} = Task.await(task, 5000)

    :ssl.close(listen)
  end
end
