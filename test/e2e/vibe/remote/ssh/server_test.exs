defmodule Vibe.E2E.Remote.SSH.ServerTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @tag timeout: 60_000
  test "foreground server exposes SSH transport on a real OS process" do
    dir =
      Path.join(System.tmp_dir!(), "vibe-ssh-server-e2e-#{System.unique_integer([:positive])}")

    port = free_port()
    original_home = Application.get_env(:vibe, :home_dir)
    Application.put_env(:vibe, :home_dir, dir)

    server = start_server_process(dir, port)

    try do
      assert {:ok, _metadata} = wait_for_metadata(port, 30_000)

      assert :ok =
               Vibe.CLI.Commands.Connect.run(["connect", "--ssh", "127.0.0.1:#{port}"],
                 yes: true
               )

      assert {:ok, connection} =
               Vibe.Remote.connect(
                 transport: :ssh,
                 host: "127.0.0.1",
                 port: port,
                 silently_accept_hosts: true
               )

      try do
        assert {:ok, %{"pong" => true}} =
                 Vibe.Remote.Transport.SSH.request(connection, %{"op" => "ping"})
      after
        Vibe.Remote.Transport.SSH.close(connection)
      end
    after
      stop_server_process(server)

      if original_home,
        do: Application.put_env(:vibe, :home_dir, original_home),
        else: Application.delete_env(:vibe, :home_dir)

      File.rm_rf!(dir)
    end
  end

  defp start_server_process(dir, port) do
    mix = System.find_executable("mix") || raise "mix executable not found"

    port_ref =
      Port.open({:spawn_executable, mix}, [
        :binary,
        :exit_status,
        {:args,
         ["vibe", "server", "start", "--foreground", "--ssh", "--port", Integer.to_string(port)]},
        {:cd, File.cwd!()},
        {:env, [{~c"VIBE_HOME", to_charlist(dir)}, {~c"MIX_ENV", ~c"test"}]}
      ])

    %{port: port_ref, os_pid: Port.info(port_ref, :os_pid) |> elem(1)}
  end

  defp stop_server_process(%{port: port, os_pid: os_pid}) do
    _ = System.cmd("kill", ["-TERM", Integer.to_string(os_pid)], stderr_to_stdout: true)

    receive do
      {^port, {:exit_status, _status}} -> :ok
    after
      5_000 ->
        _ = System.cmd("kill", ["-KILL", Integer.to_string(os_pid)], stderr_to_stdout: true)
        :ok
    end
  end

  defp wait_for_metadata(port, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    wait_for_metadata_until(port, deadline)
  end

  defp wait_for_metadata_until(port, deadline) do
    case Vibe.Server.Metadata.read() do
      {:ok, %{"ssh" => %{"port" => ^port}} = metadata} ->
        {:ok, metadata}

      _other ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(100)
          wait_for_metadata_until(port, deadline)
        end
    end
  end

  defp free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, {_address, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)
    port
  end
end
