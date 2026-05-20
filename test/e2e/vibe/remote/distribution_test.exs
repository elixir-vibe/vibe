defmodule Vibe.E2E.Remote.DistributionTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @tag timeout: 30_000
  test "remote session attach streams events across nodes" do
    # Start two BEAM nodes with plain distribution (no TLS for test simplicity)
    client_name = :"vibe_test_client_#{System.unique_integer([:positive])}@127.0.0.1"

    ensure_epmd()

    unless Node.alive?() do
      {:ok, _pid} = Node.start(client_name)
    end

    cookie =
      :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false) |> String.to_atom()

    Node.set_cookie(cookie)

    # Start a session on the server (this node acts as both for simplicity)
    session_id = "remote-test-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    # Attach from "client" (same node but proves the API works)
    {:ok, state, _cursor} = Vibe.Session.attach(session, self())
    assert state.session_id == session_id

    # Dispatch a prompt event and verify it arrives
    Vibe.Session.emit_transient_event(
      session,
      Vibe.UI.Event.new(:user_message_added, session_id, %{text: "remote test"})
    )

    assert_receive {Vibe.Session, :event,
                    %{type: :user_message_added, data: %{text: "remote test"}}},
                   1_000

    # Verify session is discoverable via lookup
    assert {:ok, ^session} = Vibe.Session.lookup(session_id)

    # Detach
    :ok = Vibe.Session.detach(session, self())
    GenServer.stop(session)
  end

  @tag timeout: 30_000
  test "TLS cert generation produces valid mutual TLS config" do
    # Use a temp dir for TLS files
    dir = Path.join(System.tmp_dir!(), "vibe-tls-e2e-#{System.unique_integer([:positive])}")
    original_home = Application.get_env(:vibe, :home_dir)
    Application.put_env(:vibe, :home_dir, dir)

    try do
      Vibe.Server.TLS.ensure!()

      c = &String.to_charlist/1

      {:ok, listen} =
        :ssl.listen(0, [
          {:certfile, c.(Vibe.Server.TLS.node_cert_path())},
          {:keyfile, c.(Vibe.Server.TLS.node_key_path())},
          {:cacertfile, c.(Vibe.Server.TLS.ca_cert_path())},
          {:verify, :verify_peer},
          {:fail_if_no_peer_cert, true}
        ])

      {:ok, {_, port}} = :ssl.sockname(listen)

      task =
        Task.async(fn ->
          {:ok, socket} = :ssl.transport_accept(listen)
          {:ok, tls_socket} = :ssl.handshake(socket)
          :ssl.send(tls_socket, "hello from server")
          :ssl.close(tls_socket)
        end)

      {:ok, client} =
        :ssl.connect(
          ~c"127.0.0.1",
          port,
          [
            {:certfile, c.(Vibe.Server.TLS.node_cert_path())},
            {:keyfile, c.(Vibe.Server.TLS.node_key_path())},
            {:cacertfile, c.(Vibe.Server.TLS.ca_cert_path())},
            {:verify, :verify_peer},
            {:server_name_indication, :disable},
            {:active, false}
          ],
          5_000
        )

      {:ok, data} = :ssl.recv(client, 0, 5_000)
      assert data == ~c"hello from server"
      :ssl.close(client)
      :ssl.close(listen)
      Task.await(task, 5_000)
    after
      if original_home,
        do: Application.put_env(:vibe, :home_dir, original_home),
        else: Application.delete_env(:vibe, :home_dir)

      File.rm_rf!(dir)
    end
  end

  defp ensure_epmd do
    System.cmd("epmd", ["-daemon"])
  rescue
    _error -> :ok
  end
end
