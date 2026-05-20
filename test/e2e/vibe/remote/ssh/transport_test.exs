defmodule Vibe.E2E.Remote.SSH.TransportTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Vibe.Remote.SSH.Daemon
  alias Vibe.Remote.Transport.SSH
  alias Vibe.UI.Event

  setup do
    dir =
      Path.join(System.tmp_dir!(), "vibe-ssh-transport-e2e-#{System.unique_integer([:positive])}")

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

  test "daemon handles constrained protocol requests and streams session events" do
    password = "secret-#{System.unique_integer([:positive])}"
    {:ok, daemon} = Daemon.start(port: 0, password: password)

    try do
      {:ok, port} = Daemon.port(daemon)

      assert {:ok, connection} =
               Vibe.Remote.connect(
                 transport: :ssh,
                 host: "127.0.0.1",
                 port: port,
                 password: password,
                 silently_accept_hosts: true
               )

      try do
        assert {:ok, %{"pong" => true, "version" => _version}} =
                 SSH.request(connection, %{"op" => "ping"})

        assert {:ok, %{"sessions" => sessions}} =
                 SSH.request(connection, %{"op" => "sessions.list"})

        assert is_list(sessions)

        session_id = "ssh-e2e-#{System.unique_integer([:positive])}"

        assert {:ok, %{"session" => %{"id" => ^session_id}}} =
                 SSH.request(connection, %{
                   "op" => "sessions.start",
                   "opts" => %{"session_id" => session_id, "persist?" => false}
                 })

        assert {:ok,
                %{"attachment_id" => attachment_id, "state" => %{"session_id" => ^session_id}}} =
                 SSH.request(connection, %{"op" => "sessions.attach", "session_id" => session_id})

        next_events =
          Task.async(fn ->
            SSH.request(connection, %{
              "op" => "sessions.next_events",
              "attachment_id" => attachment_id,
              "timeout_ms" => 2_000
            })
          end)

        assert {:ok, session} = Vibe.Session.lookup(session_id)

        Vibe.Session.emit_transient_event(
          session,
          Event.new(:notification_added, session_id, %{text: "hello over ssh"})
        )

        assert {:ok,
                %{
                  "events" => [
                    %{"type" => "notification_added", "data" => %{"text" => "hello over ssh"}}
                  ]
                }} =
                 Task.await(next_events, 3_000)

        assert {:ok, %{"detached" => true}} =
                 SSH.request(connection, %{
                   "op" => "sessions.detach",
                   "attachment_id" => attachment_id
                 })

        GenServer.stop(session)
      after
        SSH.close(connection)
      end
    after
      Daemon.stop(daemon)
    end
  end
end
